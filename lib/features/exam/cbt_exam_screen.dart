import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../services/cbt_service.dart';
import '../../services/lock_service.dart';
import 'dart:async';

class CbtExamScreen extends StatefulWidget {
  const CbtExamScreen({super.key});

  @override
  State<CbtExamScreen> createState() => _CbtExamScreenState();
}

class _CbtExamScreenState extends State<CbtExamScreen> with WidgetsBindingObserver {
  WebViewController? _controller;
  final _cbtService = CbtService();
  final _lockService = LockService();
  
  bool _isLoading = true;
  bool _isLockActive = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _violationCount = 0;
  
  StreamSubscription? _overlaySubscription;
  Timer? _securityCheckTimer;
  Timer? _loadingTimeoutTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startExamFlow();
  }

  Future<void> _startExamFlow() async {
    // Step 1: Show Permission Dialog
    final permissionGranted = await _showPermissionDialog();
    if (!permissionGranted) {
      if (mounted) context.pop();
      return;
    }

    // Step 2: Security Check Loop (until all clear)
    final securityPassed = await _securityCheckLoop();
    if (!securityPassed) {
      if (mounted) context.pop();
      return;
    }

    // Step 3: Enable Lock Mode
    final lockEnabled = await _enableLockMode();
    if (!lockEnabled) {
      if (mounted) {
        _showErrorDialog('Lock Mode Gagal', 
          'Tidak dapat mengaktifkan mode aman. Pastikan Anda mengizinkan "Screen Pinning" saat diminta.');
        await Future.delayed(const Duration(seconds: 3));
        context.pop();
      }
      return;
    }

    // Step 4: Initialize WebView
    await _initializeWebView();

    // Step 5: Start Security Monitoring
    _startSecurityMonitoring();
  }

  Future<bool> _showPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFF7C7CFF)),
            SizedBox(width: 12),
            Text('Perizinan Mode Aman', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Untuk menjaga keamanan ujian, aplikasi akan:',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text('• Mengunci layar (Screen Pinning)', style: TextStyle(color: Colors.white70)),
            Text('• Memblokir screenshot & recording', style: TextStyle(color: Colors.white70)),
            Text('• Menonaktifkan panel pintar', style: TextStyle(color: Colors.white70)),
            Text('• Menyembunyikan notifikasi', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text(
              'Anda WAJIB mengizinkan "Screen Pinning" saat diminta oleh sistem.',
              style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C7CFF)),
            child: const Text('Mengerti & Lanjutkan', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<bool> _securityCheckLoop() async {
    int attempts = 0;
    const maxAttempts = 5;

    while (attempts < maxAttempts) {
      final hasFocus = await _lockService.hasWindowFocus();
      
      if (hasFocus) {
        return true; // Security check passed
      }

      // Show alert with specific instructions
      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.red,
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 12),
              Text('Peringatan Keamanan', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Terdeteksi aplikasi/panel yang mengganggu:',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text('• Panel Pintar (Smart Panel)', style: TextStyle(color: Colors.white70)),
              Text('• Aplikasi Mengambang (Floating Apps)', style: TextStyle(color: Colors.white70)),
              Text('• Menu Asisten', style: TextStyle(color: Colors.white70)),
              SizedBox(height: 16),
              Text(
                'Silakan tutup SEMUA aplikasi/panel di atas, lalu klik "Coba Lagi".',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batalkan Ujian', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('Coba Lagi', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (retry != true) {
        return false; // User cancelled
      }

      attempts++;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Max attempts reached
    if (mounted) {
      _showErrorDialog('Gagal Memulai Ujian', 
        'Tidak dapat memulai ujian setelah $maxAttempts percobaan. Pastikan semua overlay ditutup.');
    }
    return false;
  }

  Future<bool> _enableLockMode() async {
    try {
      await _lockService.startLockTask();
      await _lockService.setSecureFlag();
      await _lockService.disableGestureNavigation();
      
      // Validate lock mode is active
      await Future.delayed(const Duration(milliseconds: 500));
      final isActive = await _lockService.isLockModeActive();
      
      if (isActive) {
        setState(() => _isLockActive = true);
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error enabling lock mode: $e');
      return false;
    }
  }

  Future<void> _initializeWebView() async {
    try {
      final url = await _cbtService.getCbtUrl();
      
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFFFFFFF))
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              // Could update progress indicator here
            },
            onPageStarted: (String url) {
              debugPrint('Page started loading: $url');
            },
            onPageFinished: (String url) {
              debugPrint('Page finished loading: $url');
              _loadingTimeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('WebView error: ${error.description}');
              _loadingTimeoutTimer?.cancel();
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = 'Gagal memuat halaman: ${error.description}';
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(url));

      // Set timeout for loading
      _loadingTimeoutTimer = Timer(const Duration(seconds: 30), () {
        if (_isLoading && mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = 'Timeout: Halaman tidak dapat dimuat dalam 30 detik';
            _isLoading = false;
          });
        }
      });

      // Listen for overlays
      _overlaySubscription = _lockService.onOverlayDetected.listen((_) {
        _handleSecurityViolation();
      });

      setState(() {}); // Trigger rebuild with controller
    } catch (e) {
      debugPrint('Error initializing WebView: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _startSecurityMonitoring() {
    _securityCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (!mounted || !_isLockActive) {
        timer.cancel();
        return;
      }

      final hasFocus = await _lockService.hasWindowFocus();
      if (!hasFocus) {
        _handleSecurityViolation();
      }
    });
  }

  void _handleSecurityViolation() {
    _violationCount++;
    
    if (_violationCount >= 3) {
      _autoSubmitExam();
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.red,
          title: const Text('PELANGGARAN KEAMANAN!', style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Terdeteksi overlay/panel pintar!\nPelanggaran: $_violationCount/3',
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'Tutup segera atau ujian akan otomatis disubmit!',
                style: TextStyle(color: Colors.white70, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('Sudah Ditutup', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _autoSubmitExam() async {
    await _disableLockMode();
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.red,
          title: const Text('UJIAN OTOMATIS DISUBMIT', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Terlalu banyak pelanggaran keamanan. Ujian Anda telah disubmit secara otomatis.',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('OK', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _disableLockMode() async {
    await _lockService.stopLockTask();
    await _lockService.clearSecureFlag();
    await _lockService.enableGestureNavigation();
    setState(() => _isLockActive = false);
  }

  Future<void> _handleExit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2D2D44),
        title: const Text('Selesai Ujian?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Apakah Anda yakin ingin menyelesaikan dan keluar dari ujian?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Selesai & Keluar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _disableLockMode();
      if (mounted) context.pop();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isLockActive) {
      _enableLockMode(); // Re-enforce
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlaySubscription?.cancel();
    _securityCheckTimer?.cancel();
    _loadingTimeoutTimer?.cancel();
    _disableLockMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Stack(
            children: [
              // WebView
              if (_controller != null && !_isLoading && !_hasError)
                WebViewWidget(controller: _controller!),
              
              // Loading Indicator
              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Memuat halaman ujian...'),
                    ],
                  ),
                ),

              // Error Display
              if (_hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              _isLoading = true;
                              _hasError = false;
                            });
                            await _initializeWebView();
                          },
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),

              // Native Exit Button (Always Visible)
              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: _handleExit,
                  backgroundColor: Colors.red,
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  label: const Text('Selesai Ujian', style: TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

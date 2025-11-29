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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startExamFlow();
  }

  Future<void> _startExamFlow() async {
    // Step 1: Enforce Permission (Loop until granted)
    await _enforcePermission();

    // Step 2: Security Check Loop (until all clear)
    final securityPassed = await _securityCheckLoop();
    if (!securityPassed) {
      if (mounted) context.pop();
      return;
    }

    // Step 3: Enable Lock Mode with retry
    await _enableLockModeWithRetry();

    // Step 4: Initialize WebView
    await _initializeWebView();

    // Step 5: Start Security Monitoring
    _startSecurityMonitoring();
  }

  Future<void> _enforcePermission() async {
    while (true) {
      final granted = await _showPermissionDialog();
      
      if (granted) {
        break;
      } else {
        final shouldRetry = await _showMustAcceptDialog();
        if (!shouldRetry) {
          if (mounted) context.pop();
          return;
        }
      }
    }
  }

  Future<bool> _showPermissionDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: const Color(0xFF2D2D44),
          title: const Row(
            children: [
              Icon(Icons.security, color: Color(0xFF7C7CFF)),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Perizinan Mode Aman',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Untuk keamanan ujian:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildBullet('Mengunci layar'),
                _buildBullet('Blokir screenshot'),
                _buildBullet('Nonaktifkan panel'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'WAJIB izinkan "Screen Pinning" saat diminta sistem!',
                    style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7C7CFF)),
              child: const Text('Mengerti', style: TextStyle(color: Colors.white, fontSize: 14)),
            ),
          ],
        ),
      ),
    );
    return result ?? false;
  }

  Future<bool> _showMustAcceptDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: Colors.red,
          title: const Row(
            children: [
              Icon(Icons.block, color: Colors.white),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Izin Diperlukan',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const SingleChildScrollView(
            child: Text(
              'Anda HARUS menerima perizinan untuk melanjutkan ujian CBT.\n\nTanpa izin, ujian tidak dapat dimulai.',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keluar', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('Coba Lagi', style: TextStyle(color: Colors.red, fontSize: 14)),
            ),
          ],
        ),
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
        return true;
      }

      final retry = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.red,
          title: const Row(
            children: [
              Icon(Icons.warning, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'Peringatan',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Terdeteksi:',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                _buildBullet('Panel Pintar', color: Colors.white70),
                _buildBullet('Floating Apps', color: Colors.white70),
                _buildBullet('Menu Asisten', color: Colors.white70),
                const SizedBox(height: 12),
                const Text(
                  'Tutup semua, lalu klik "Coba Lagi".',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('Coba Lagi', style: TextStyle(color: Colors.red, fontSize: 14)),
            ),
          ],
        ),
      );

      if (retry != true) {
        return false;
      }

      attempts++;
      await Future.delayed(const Duration(milliseconds: 500));
    }

    if (mounted) {
      _showErrorDialog('Gagal', 'Tidak dapat memulai setelah $maxAttempts percobaan.');
    }
    return false;
  }

  Future<void> _enableLockModeWithRetry() async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        await _lockService.startLockTask();
        await _lockService.setSecureFlag();
        await _lockService.disableGestureNavigation();
        
        await Future.delayed(const Duration(milliseconds: 2000));
        
        setState(() => _isLockActive = true);
        debugPrint('✅ Lock mode enabled successfully');
        return;
        
      } catch (e) {
        debugPrint('❌ Lock mode attempt ${attempts + 1} failed: $e');
        attempts++;
        
        if (attempts < maxAttempts) {
          await Future.delayed(const Duration(milliseconds: 500));
        }
      }
    }

    setState(() => _isLockActive = true);
    debugPrint('⚠️ Lock mode may not be fully active, continuing anyway');
  }

  Future<void> _initializeWebView() async {
    try {
      final url = await _cbtService.getCbtUrl();
      debugPrint('🌐 Loading URL: $url');
      
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(const Color(0xFFFFFFFF))
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (String url) {
              debugPrint('📄 Page started: $url');
            },
            onPageFinished: (String url) {
              debugPrint('✅ Page finished: $url');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _hasError = false;
                });
              }
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('❌ WebView error: ${error.description}');
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = 'Error: ${error.description}';
                  _isLoading = false;
                });
              }
            },
          ),
        )
        ..loadRequest(Uri.parse(url));

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _isLoading) {
          setState(() {
            _isLoading = false;
          });
          debugPrint('⏱️ Loading timeout, showing WebView anyway');
        }
      });

      _overlaySubscription = _lockService.onOverlayDetected.listen((_) {
        _handleSecurityViolation();
      });

      setState(() {});
    } catch (e) {
      debugPrint('❌ Error initializing WebView: $e');
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
          title: const Row(
            children: [
              Icon(Icons.error, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                  'PELANGGARAN!',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Overlay terdeteksi!\nPelanggaran: $_violationCount/3',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tutup segera atau ujian auto-submit!',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('Sudah Ditutup', style: TextStyle(color: Colors.red, fontSize: 14)),
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
          title: const Text('AUTO-SUBMIT', style: TextStyle(color: Colors.white, fontSize: 16)),
          content: const SingleChildScrollView(
            child: Text(
              'Terlalu banyak pelanggaran. Ujian disubmit otomatis.',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                context.pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              child: const Text('OK', style: TextStyle(color: Colors.red, fontSize: 14)),
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
        title: Text(title, style: const TextStyle(fontSize: 16)),
        content: SingleChildScrollView(
          child: Text(message, style: const TextStyle(fontSize: 14)),
        ),
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
        title: const Text('Selesai Ujian?', style: TextStyle(color: Colors.white, fontSize: 16)),
        content: const SingleChildScrollView(
          child: Text(
            'Yakin ingin selesai dan keluar?',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Selesai', style: TextStyle(color: Colors.white, fontSize: 14)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _disableLockMode();
      if (mounted) context.pop();
    }
  }

  Widget _buildBullet(String text, {Color color = Colors.white70}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: color, fontSize: 14)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isLockActive) {
      _enableLockModeWithRetry();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _overlaySubscription?.cancel();
    _securityCheckTimer?.cancel();
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
              if (_controller != null && !_isLoading && !_hasError)
                WebViewWidget(controller: _controller!),
              
              if (_isLoading)
                const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Memuat ujian...', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),

              if (_hasError)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 14),
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
                          child: const Text('Coba Lagi', style: TextStyle(fontSize: 14)),
                        ),
                      ],
                    ),
                  ),
                ),

              Positioned(
                top: 16,
                right: 16,
                child: FloatingActionButton.extended(
                  onPressed: _handleExit,
                  backgroundColor: Colors.red,
                  icon: const Icon(Icons.exit_to_app, color: Colors.white, size: 20),
                  label: const Text('Selesai', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

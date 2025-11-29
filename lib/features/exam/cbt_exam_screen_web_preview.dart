import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:go_router/go_router.dart';
import '../../services/cbt_service.dart';
import 'dart:async';
// Conditional import for web
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

/// WEB PREVIEW VERSION FOR CHROME TESTING
/// Uses iframe for web, WebView for mobile
class CbtExamScreenWebPreview extends StatefulWidget {
  const CbtExamScreenWebPreview({super.key});

  @override
  State<CbtExamScreenWebPreview> createState() => _CbtExamScreenWebPreviewState();
}

class _CbtExamScreenWebPreviewState extends State<CbtExamScreenWebPreview> {
  final _cbtService = CbtService();
  
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String? _iframeViewType;
  
  Timer? _loadingTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    try {
      final url = await _cbtService.getCbtUrl();
      debugPrint('🌐 CBT URL to load: $url');
      
      if (kIsWeb) {
        // For web platform, use iframe
        _iframeViewType = 'cbt-iframe-${DateTime.now().millisecondsSinceEpoch}';
        
        // Register iframe view factory
        // ignore: undefined_prefixed_name
        ui_web.platformViewRegistry.registerViewFactory(
          _iframeViewType!,
          (int viewId) {
            debugPrint('📦 Creating iframe for: $url');
            
            final iframe = html.IFrameElement()
              ..src = url
              ..style.border = 'none'
              ..style.width = '100%'
              ..style.height = '100%'
              ..allow = 'accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture';
            
            debugPrint('✅ Iframe element created and registered');
            return iframe;
          },
        );
        
        // Give iframe time to register, then show it
        // Note: onLoad event doesn't always fire with HtmlElementView in Flutter
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _hasError = false;
            });
            debugPrint('✅ Iframe should now be visible');
          }
        });
        
        setState(() {
          debugPrint('🔄 State updated, iframe registered');
        });
      } else {
        // For mobile, show message to use production version
        setState(() {
          _hasError = true;
          _errorMessage = 'Web Preview hanya untuk Chrome. Gunakan Android device untuk testing penuh.';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error initializing WebView: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Error saat inisialisasi:\n$e\n\n'
              'Coba refresh halaman atau restart aplikasi.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleExit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Keluar dari Preview?'),
        content: const Text('Apakah Anda yakin ingin keluar?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.pop();
    }
  }

  @override
  void dispose() {
    _loadingTimeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.orange,
        title: const Text('CBT Preview Mode (Testing Only)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _handleExit,
            tooltip: 'Keluar',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Iframe for web
          if (kIsWeb && _iframeViewType != null && !_isLoading && !_hasError)
            HtmlElementView(viewType: _iframeViewType!),
          
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
        ],
      ),
    );
  }
}

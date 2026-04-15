import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';

class WebPageScreen extends StatefulWidget {
  const WebPageScreen({required this.title, required this.url, super.key});

  final String title;
  final String url;

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  late final WebViewWidget _webView;

  // All reactive state lives in ValueNotifiers — zero setState calls,
  // so the WebView widget tree is never dirtied during page loads.
  final ValueNotifier<int> _progress = ValueNotifier<int>(0);
  final ValueNotifier<bool> _hasError = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _errorMessage = ValueNotifier<String?>(null);

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            _hasError.value = false;
            _errorMessage.value = null;
            _progress.value = 0;
          },
          onProgress: (progress) {
            if (_progress.value != progress) {
              _progress.value = progress;
            }
          },
          onPageFinished: (_) {
            _progress.value = 100;
          },
          onWebResourceError: (error) {
            if (!_isMainFrameError(error)) return;
            _hasError.value = true;
            _errorMessage.value = _friendlyErrorMessage(error);
            _progress.value = 100;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    // Created once, never rebuilt — this is the key to eliminating jank.
    _webView = WebViewWidget(controller: _controller);
  }

  bool _isMainFrameError(WebResourceError error) {
    final isMainFrame = error.isForMainFrame;
    return isMainFrame == null || isMainFrame;
  }

  String _friendlyErrorMessage(WebResourceError error) {
    final lower = error.description.trim().toLowerCase();
    if (lower.contains('internet') ||
        lower.contains('network') ||
        lower.contains('host lookup') ||
        lower.contains('timeout') ||
        lower.contains('connection')) {
      return 'Check your internet connection and try again.';
    }
    if (lower.contains('404') ||
        lower.contains('not found') ||
        lower.contains('unsupported')) {
      return 'This page is not available right now.';
    }
    return 'This page could not be loaded right now.';
  }

  Future<void> _reload() async {
    _hasError.value = false;
    _errorMessage.value = null;
    _progress.value = 0;
    await _controller.reload();
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  void dispose() {
    _progress.dispose();
    _hasError.dispose();
    _errorMessage.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (kIsWeb) {
      return Scaffold(
        backgroundColor: colors.scaffold,
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: 'Open in browser',
              onPressed: _openInBrowser,
              icon: const Icon(Icons.open_in_browser_rounded),
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.web_rounded, size: 64, color: colors.icon),
              const SizedBox(height: 16),
              Text(
                'WebView not available on web',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Tap the button above to open in your browser',
                style: TextStyle(color: colors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _openInBrowser,
                icon: const Icon(Icons.open_in_browser_rounded),
                label: const Text('Open in Browser'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.scaffold,
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: ValueListenableBuilder<int>(
            valueListenable: _progress,
            builder: (context, progress, _) {
              if (progress >= 100) return const SizedBox.shrink();
              return LinearProgressIndicator(value: progress / 100);
            },
          ),
        ),
      ),
      // Stack keeps the WebView permanently mounted so the platform view
      // is never torn down and recreated — the #1 cause of jank on first open.
      body: Stack(
        fit: StackFit.expand,
        children: [
          // WebView sits at the bottom of the stack, always alive.
          RepaintBoundary(child: _webView),

          // Error overlay floats on top; the WebView beneath is untouched.
          ValueListenableBuilder<bool>(
            valueListenable: _hasError,
            builder: (context, hasError, _) {
              if (!hasError) return const SizedBox.shrink();
              return ValueListenableBuilder<String?>(
                valueListenable: _errorMessage,
                builder: (context, message, _) {
                  return _WebPageErrorState(
                    title: widget.title,
                    message: message ?? 'This page could not be loaded right now.',
                    onRetry: _reload,
                    onOpenInBrowser: _openInBrowser,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WebPageErrorState extends StatelessWidget {
  const _WebPageErrorState({
    required this.title,
    required this.message,
    required this.onRetry,
    required this.onOpenInBrowser,
  });

  final String title;
  final String message;
  final Future<void> Function() onRetry;
  final Future<void> Function() onOpenInBrowser;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
            decoration: BoxDecoration(
              color: colors.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: colors.border),
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.08),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                  spreadRadius: -18,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: context.appColors.brandGradient,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.wifi_off_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Unable to open page',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try again'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onOpenInBrowser,
                  icon: const Icon(Icons.open_in_browser_rounded),
                  label: const Text('Open in browser'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
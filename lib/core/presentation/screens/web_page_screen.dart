import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hopefulme_flutter/app/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

typedef WebPageInternalLinkHandler = Future<bool> Function(Uri uri);

class WebPageScreen extends StatefulWidget {
  const WebPageScreen({
    required this.title,
    required this.url,
    this.onInternalLinkTap,
    super.key,
  });

  final String title;
  final String url;
  final WebPageInternalLinkHandler? onInternalLinkTap;

  static bool shouldUseNativeRouting(Uri uri, {String? originUrl}) {
    final host = uri.host.trim().toLowerCase();
    final configuredHost = Uri.tryParse(originUrl ?? '')?.host.toLowerCase();
    final allowedHosts = <String>{
      if (configuredHost != null && configuredHost.isNotEmpty) configuredHost,
      'ahopefulme.com',
      'www.ahopefulme.com',
    };

    if (host.isEmpty || !allowedHosts.contains(host)) {
      return false;
    }

    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .map((segment) => segment.trim().toLowerCase())
        .toList(growable: false);
    if (segments.isEmpty) {
      return true;
    }

    final head = segments.first;
    if (head == 'home') {
      return true;
    }
    if (head.startsWith('@')) {
      return true;
    }

    if (head == 'profile' && segments.length >= 2) {
      return true;
    }

    const nativeHeads = <String>{
      'updates',
      'social',
      'posts',
      'post',
      'blog',
      'library',
      'chat',
      'groups',
      'community',
      'search',
      'inspire',
    };
    if (nativeHeads.contains(head)) {
      return true;
    }

    if (segments.length == 1 && !_reservedProfileLikePath(head)) {
      return true;
    }

    return false;
  }

  static bool _reservedProfileLikePath(String segment) {
    const reserved = <String>{
      'about',
      'admin',
      'adverts',
      'api',
      'auth',
      'blog',
      'chat',
      'community',
      'contact',
      'games',
      'groups',
      'home',
      'inspire',
      'library',
      'login',
      'logout',
      'more-menu',
      'myprofile',
      'notifications',
      'outreach',
      'partnership',
      'play',
      'post',
      'posts',
      'privacy',
      'profile',
      'register',
      'search',
      'settings',
      'social',
      'store',
      'terms',
      'tv',
      'updates',
      'volunteer',
      'welcome',
    };

    return reserved.contains(segment);
  }

  @override
  State<WebPageScreen> createState() => _WebPageScreenState();
}

class _WebPageScreenState extends State<WebPageScreen> {
  late final WebViewController _controller;
  late final WebViewWidget _webView;

  final ValueNotifier<int> _progress = ValueNotifier<int>(0);
  final ValueNotifier<bool> _hasError = ValueNotifier<bool>(false);
  final ValueNotifier<String?> _errorMessage = ValueNotifier<String?>(null);
  bool _isShowingFallbackDocument = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;

    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (_isShowingFallbackDocument) {
              _progress.value = 100;
              return;
            }
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
            if (_isShowingFallbackDocument) {
              _progress.value = 100;
              return;
            }
            _progress.value = 100;
          },
          onWebResourceError: (error) {
            if (!_isMainFrameError(error)) return;
            _hasError.value = true;
            _errorMessage.value = _friendlyErrorMessage(error);
            _progress.value = 100;
            unawaited(_showFallbackDocument());
          },
          onNavigationRequest: (request) async {
            final linkHandler = widget.onInternalLinkTap;
            if (linkHandler == null) {
              return NavigationDecision.navigate;
            }

            final uri = Uri.tryParse(request.url);
            if (uri == null ||
                !WebPageScreen.shouldUseNativeRouting(
                  uri,
                  originUrl: widget.url,
                )) {
              return NavigationDecision.navigate;
            }

            final handled = await linkHandler(uri);
            return handled
                ? NavigationDecision.prevent
                : NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    if (controller.platform is AndroidWebViewController) {
      final androidController = controller.platform as AndroidWebViewController;
      unawaited(
        androidController.setOnShowFileSelector(_selectFilesForWebInput),
      );
    }

    _controller = controller;
    _webView = WebViewWidget(controller: _controller);
  }

  Future<List<String>> _selectFilesForWebInput(
    FileSelectorParams params,
  ) async {
    if (params.mode == FileSelectorMode.save) {
      return const <String>[];
    }

    final allowMultiple = params.mode == FileSelectorMode.openMultiple;
    final fileType = _pickFileTypeFromAcceptTypes(params.acceptTypes);
    final allowedExtensions = fileType == FileType.custom
        ? _extractExtensions(params.acceptTypes)
        : null;

    final selected = await FilePicker.platform.pickFiles(
      allowMultiple: allowMultiple,
      type: fileType,
      allowedExtensions: allowedExtensions == null || allowedExtensions.isEmpty
          ? null
          : allowedExtensions,
      withData: false,
    );

    if (selected == null || selected.files.isEmpty) {
      return const <String>[];
    }

    return selected.files
        .map(_platformFileToWebViewUri)
        .whereType<String>()
        .toList(growable: false);
  }

  String? _platformFileToWebViewUri(PlatformFile file) {
    final path = file.path;
    if (path != null && path.trim().isNotEmpty) {
      return Uri.file(path).toString();
    }

    final identifier = file.identifier;
    if (identifier != null && identifier.trim().isNotEmpty) {
      return identifier;
    }

    return null;
  }

  FileType _pickFileTypeFromAcceptTypes(List<String> acceptTypes) {
    final normalized = acceptTypes
        .map((type) => type.trim().toLowerCase())
        .where((type) => type.isNotEmpty && type != '*/*')
        .toList(growable: false);

    if (normalized.isEmpty) {
      return FileType.any;
    }

    final onlyImages = normalized.every(
      (type) => type.startsWith('image/') || _looksLikeImageExtension(type),
    );
    if (onlyImages) {
      return FileType.image;
    }

    final onlyVideos = normalized.every(
      (type) => type.startsWith('video/') || _looksLikeVideoExtension(type),
    );
    if (onlyVideos) {
      return FileType.video;
    }

    final onlyAudio = normalized.every(
      (type) => type.startsWith('audio/') || _looksLikeAudioExtension(type),
    );
    if (onlyAudio) {
      return FileType.audio;
    }

    final customExtensions = _extractExtensions(normalized);
    if (customExtensions.isNotEmpty) {
      return FileType.custom;
    }

    return FileType.any;
  }

  List<String> _extractExtensions(List<String> acceptTypes) {
    final extensions = <String>{};
    for (final raw in acceptTypes) {
      final value = raw.trim().toLowerCase();
      if (value.isEmpty || value == '*/*') {
        continue;
      }

      if (value.startsWith('.')) {
        extensions.add(value.substring(1));
        continue;
      }

      if (!value.contains('/')) {
        extensions.add(value.replaceFirst('.', ''));
      }
    }
    return extensions.toList(growable: false);
  }

  bool _looksLikeImageExtension(String value) =>
      value == '.jpg' ||
      value == '.jpeg' ||
      value == '.png' ||
      value == '.gif' ||
      value == '.webp' ||
      value == 'jpg' ||
      value == 'jpeg' ||
      value == 'png' ||
      value == 'gif' ||
      value == 'webp';

  bool _looksLikeVideoExtension(String value) =>
      value == '.mp4' ||
      value == '.mov' ||
      value == '.avi' ||
      value == '.mkv' ||
      value == '.webm' ||
      value == 'mp4' ||
      value == 'mov' ||
      value == 'avi' ||
      value == 'mkv' ||
      value == 'webm';

  bool _looksLikeAudioExtension(String value) =>
      value == '.mp3' ||
      value == '.wav' ||
      value == '.m4a' ||
      value == '.ogg' ||
      value == 'mp3' ||
      value == 'wav' ||
      value == 'm4a' ||
      value == 'ogg';

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
    _isShowingFallbackDocument = false;
    _hasError.value = false;
    _errorMessage.value = null;
    _progress.value = 0;
    await _controller.reload();
  }

  Future<void> _showFallbackDocument() async {
    _isShowingFallbackDocument = true;
    try {
      await _controller.loadHtmlString(
        '<!doctype html><html><head><meta charset="utf-8"></head><body style="margin:0;background:transparent;"></body></html>',
      );
    } catch (_) {
      // Ignore fallback injection failures; the custom error overlay remains.
    }
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(child: _webView),
          ValueListenableBuilder<bool>(
            valueListenable: _hasError,
            builder: (context, hasError, _) {
              if (!hasError) return const SizedBox.shrink();
              return ValueListenableBuilder<String?>(
                valueListenable: _errorMessage,
                builder: (context, message, _) {
                  return _WebPageErrorState(
                    title: widget.title,
                    message:
                        message ?? 'This page could not be loaded right now.',
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

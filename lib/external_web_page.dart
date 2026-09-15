import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'browser_hint.dart';
import 'deposit_link_prompt.dart';
import 'external_scheme.dart';
import 'web_environment.dart';

class ExternalWebPage extends StatefulWidget {
  const ExternalWebPage({
    super.key,
    this.initialUrl,
    this.windowId,
    this.promptDepositLink = false,
  }) : assert(initialUrl != null || windowId != null);

  final WebUri? initialUrl;
  final int? windowId;
  final bool promptDepositLink;

  @override
  State<ExternalWebPage> createState() => _ExternalWebPageState();
}

class _ExternalWebPageState extends State<ExternalWebPage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  String _title = '正在加载';
  bool _browserHintAllowed = false;
  bool _browserHintPrompting = false;
  bool _depositPromptPending = false;
  bool _depositPromptAllowed = false;
  bool _depositPrompting = false;

  @override
  void initState() {
    super.initState();
    _depositPromptPending = widget.promptDepositLink;
  }

  static const SystemUiOverlayStyle _systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarBrightness: Brightness.light,
    statusBarIconBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarDividerColor: Colors.transparent,
  );

  Future<void> _closePage() async {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleSystemBack() async {
    final controller = _controller;
    if (controller != null && await controller.canGoBack()) {
      await controller.goBack();
      return;
    }
    await _closePage();
  }

  Future<bool> _handleBrowserHintUrl(
    InAppWebViewController controller,
    WebUri? url, {
    bool stopCurrentLoad = false,
  }) async {
    if (_browserHintAllowed ||
        _browserHintPrompting ||
        !isBrowserHintUrl(url)) {
      return false;
    }

    _browserHintPrompting = true;
    if (stopCurrentLoad) {
      await controller.stopLoading();
    }

    if (!mounted) {
      _browserHintPrompting = false;
      return false;
    }

    final action = await getBrowserHintAction(context, url!);
    _browserHintPrompting = false;

    if (action == BrowserHintAction.browser) {
      await openSystemBrowser(url);
      await _closePage();
      return true;
    }

    _browserHintAllowed = true;
    if (stopCurrentLoad) {
      await controller.loadUrl(urlRequest: URLRequest(url: url));
    }
    return true;
  }

  Future<bool> _handleExternalSchemeUrl(
    InAppWebViewController controller,
    WebUri? url, {
    bool stopCurrentLoad = false,
  }) async {
    if (!isExternalSchemeUrl(url)) {
      return false;
    }

    if (stopCurrentLoad) {
      await controller.stopLoading();
    }

    await openExternalScheme(url!);
    return true;
  }

  Future<bool> _handleDepositLinkUrl(
    InAppWebViewController controller,
    WebUri? url, {
    bool stopCurrentLoad = false,
  }) async {
    if (!_depositPromptPending ||
        _depositPromptAllowed ||
        _depositPrompting ||
        !isWebUrl(url)) {
      return false;
    }

    _depositPrompting = true;
    if (stopCurrentLoad) {
      await controller.stopLoading();
    }

    if (!mounted) {
      _depositPrompting = false;
      return false;
    }

    final action = await showDepositLinkPrompt(context);
    _depositPrompting = false;
    _depositPromptPending = false;

    if (action == DepositLinkAction.browser) {
      await openSystemBrowser(url!);
      await _closePage();
      return true;
    }

    _depositPromptAllowed = true;
    if (stopCurrentLoad) {
      await controller.loadUrl(urlRequest: URLRequest(url: url));
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: _systemUiStyle,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (!didPop) {
            await _handleSystemBack();
          }
        },
        child: Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF0F172A),
            elevation: 0,
            surfaceTintColor: Colors.white,
            centerTitle: true,
            leading: IconButton(
              tooltip: '返回',
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: _closePage,
            ),
            title: Text(
              _title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: SizedBox(
                height: 2,
                child: _progress > 0 && _progress < 1
                    ? LinearProgressIndicator(
                        value: _progress,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
          body: SafeArea(
            top: false,
            maintainBottomViewPadding: true,
            child: InAppWebView(
              windowId: widget.windowId,
              initialUrlRequest: widget.windowId == null
                  ? URLRequest(url: widget.initialUrl)
                  : null,
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                cacheEnabled: true,
                cacheMode: CacheMode.LOAD_CACHE_ELSE_NETWORK,
                clearCache: false,
                userAgent: appBrowserUserAgent,
                domStorageEnabled: true,
                databaseEnabled: true,
                thirdPartyCookiesEnabled: true,
                sharedCookiesEnabled: true,
                useWideViewPort: true,
                loadWithOverviewMode: true,
                supportZoom: false,
                builtInZoomControls: false,
                displayZoomControls: false,
                allowsBackForwardNavigationGestures: false,
                mediaPlaybackRequiresUserGesture: false,
                allowsInlineMediaPlayback: true,
                useShouldOverrideUrlLoading: true,
                supportMultipleWindows: false,
              ),
              initialUserScripts: UnmodifiableListView<UserScript>(
                <UserScript>[buildPlatformUserScript()],
              ),
              onWebViewCreated: (controller) {
                _controller = controller;
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                if (!navigationAction.isForMainFrame) {
                  return NavigationActionPolicy.ALLOW;
                }

                final externalSchemeHandled = await _handleExternalSchemeUrl(
                  controller,
                  navigationAction.request.url,
                );
                if (externalSchemeHandled) {
                  return NavigationActionPolicy.CANCEL;
                }

                final depositLinkHandled = await _handleDepositLinkUrl(
                  controller,
                  navigationAction.request.url,
                );
                if (depositLinkHandled && !_depositPromptAllowed) {
                  return NavigationActionPolicy.CANCEL;
                }

                final handled = await _handleBrowserHintUrl(
                  controller,
                  navigationAction.request.url,
                );
                if (handled && !_browserHintAllowed) {
                  return NavigationActionPolicy.CANCEL;
                }

                return NavigationActionPolicy.ALLOW;
              },
              onLoadStart: (controller, url) async {
                await injectPlatformEnvironment(controller);
                await _handleExternalSchemeUrl(
                  controller,
                  url,
                  stopCurrentLoad: true,
                );
                await _handleDepositLinkUrl(
                  controller,
                  url,
                  stopCurrentLoad: true,
                );
                await _handleBrowserHintUrl(
                  controller,
                  url,
                  stopCurrentLoad: true,
                );
              },
              onTitleChanged: (controller, title) {
                if (title == null || title.trim().isEmpty) {
                  return;
                }
                setState(() {
                  _title = title.trim();
                });
              },
              onProgressChanged: (controller, progress) {
                setState(() {
                  _progress = progress / 100;
                });
              },
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'browser_hint.dart';
import 'deposit_link_prompt.dart';
import 'domain_resolver.dart';
import 'external_scheme.dart';
import 'external_web_page.dart';
import 'app_config.dart';
import 'web_environment.dart';

const SystemUiOverlayStyle _systemUiStyle = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarBrightness: Brightness.light,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.white,
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Colors.transparent,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(_systemUiStyle);
  await SystemChrome.setPreferredOrientations(<DeviceOrientation>[
    DeviceOrientation.portraitUp,
  ]);
  runApp(const SdApp());
}

class SdApp extends StatelessWidget {
  const SdApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0F766E)),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      builder: (context, child) {
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: _systemUiStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: const BootstrapPage(),
    );
  }
}

class BootstrapPage extends StatefulWidget {
  const BootstrapPage({super.key});

  @override
  State<BootstrapPage> createState() => _BootstrapPageState();
}

class _BootstrapPageState extends State<BootstrapPage> {
  late Future<String> _domainFuture;
  late Future<PackageInfo> _packageInfoFuture;
  final DomainResolver _resolver = DomainResolver();

  @override
  void initState() {
    super.initState();
    _domainFuture = _resolveAfterMinimumLoadingTime();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  void _retry() {
    setState(() {
      _domainFuture = _resolveAfterMinimumLoadingTime();
    });
  }

  Future<String> _resolveAfterMinimumLoadingTime() async {
    final results = await Future.wait<Object>(<Future<Object>>[
      _resolver.resolve(),
      Future<Object>.delayed(
        const Duration(milliseconds: 1500),
        () => Object(),
      ),
    ]);
    return results.first as String;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _domainFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return WebContainer(initialUrl: snapshot.requireData);
        }

        if (snapshot.hasError) {
          return ResolveErrorView(
            message: snapshot.error.toString(),
            onRetry: _retry,
          );
        }

        return SplashView(packageInfoFuture: _packageInfoFuture);
      },
    );
  }
}

class WebContainer extends StatefulWidget {
  const WebContainer({
    super.key,
    required this.initialUrl,
  });

  final String initialUrl;

  @override
  State<WebContainer> createState() => _WebContainerState();
}

class _WebContainerState extends State<WebContainer>
    with WidgetsBindingObserver {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _isDepositRoute = false;
  bool _reloadMainOnResume = false;
  bool _skipFrontendSplashEnabled = false;
  late final Uri _mainDomainUri;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mainDomainUri = Uri.parse(widget.initialUrl);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _reloadMainOnResume) {
      _reloadMainOnResume = false;
      _reloadMainWebView();
    }
  }

  bool _shouldOpenInSubPage(WebUri? url) {
    if (url == null) {
      return false;
    }

    final uri = Uri.tryParse(url.toString());
    if (uri == null) {
      return false;
    }

    if (!isWebUrl(url)) {
      return false;
    }

    return uri.host.isNotEmpty && uri.host != _mainDomainUri.host;
  }

  void _syncCurrentRoute(WebUri? url) {
    if (url == null) {
      return;
    }

    final rawUrl = url.toString();
    final isDepositRoute = rawUrl.contains('#/mobile/deposit') ||
        rawUrl.contains('#!mobile/deposit');
    _isDepositRoute = isDepositRoute;
  }

  Future<bool> _handleExternalUrl(WebUri url) async {
    if (_isDepositRoute) {
      final action = await showDepositLinkPrompt(context);
      if (action == DepositLinkAction.browser) {
        _markReloadMainOnReturn();
        final launched = await openSystemBrowser(url);
        if (!launched) {
          await _openSubPage(url);
        }
        return true;
      }
    }

    if (!mounted) {
      return true;
    }

    if (isBrowserHintUrl(url)) {
      final action = await getBrowserHintAction(context, url);
      if (action == BrowserHintAction.browser) {
        _markReloadMainOnReturn();
        final launched = await openSystemBrowser(url);
        if (!launched) {
          await _openSubPage(url);
        }
        return true;
      }
    }

    await _openSubPage(url);
    return true;
  }

  Future<void> _openSubPage(WebUri url) async {
    _markReloadMainOnReturn();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ExternalWebPage(
          initialUrl: url,
          promptDepositLink: false,
        ),
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    await _reloadMainWebView();
  }

  Future<void> _openWindowSubPage(
    int windowId,
    WebUri? fallbackUrl, {
    required bool promptDepositLink,
  }) async {
    _markReloadMainOnReturn();
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) =>
            ExternalWebPage(
          windowId: windowId,
          initialUrl: fallbackUrl,
          promptDepositLink: promptDepositLink,
        ),
        transitionDuration: const Duration(milliseconds: 180),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
    await _reloadMainWebView();
  }

  void _markReloadMainOnReturn() {
    _reloadMainOnResume = true;
  }

  Future<void> _enableSkipFrontendSplash(
    InAppWebViewController controller,
  ) async {
    if (_skipFrontendSplashEnabled) {
      return;
    }

    _skipFrontendSplashEnabled = true;
    await injectSkipFrontendSplash(controller);
    await controller.addUserScript(
      userScript: buildSkipFrontendSplashUserScript(),
    );
  }

  Future<void> _reloadMainWebView() async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) {
      return;
    }

    await _controller?.reload();
    _reloadMainOnResume = false;
  }

  @override
  Widget build(BuildContext context) {
    final initialUri = WebUri(widget.initialUrl);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }

        final controller = _controller;
        if (controller != null && await controller.canGoBack()) {
          await controller.goBack();
          return;
        }

        SystemNavigator.pop();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          maintainBottomViewPadding: true,
          child: Stack(
            children: <Widget>[
              InAppWebView(
                initialUrlRequest: URLRequest(url: initialUri),
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
                  alwaysBounceHorizontal: false,
                  disableHorizontalScroll: true,
                  isDirectionalLockEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                  supportMultipleWindows: true,
                  useShouldOverrideUrlLoading: true,
                ),
                initialUserScripts: UnmodifiableListView<UserScript>(
                  <UserScript>[buildPlatformUserScript()],
                ),
                onWebViewCreated: (controller) {
                  _controller = controller;
                },
                onLoadStart: (controller, url) async {
                  _syncCurrentRoute(url);
                  await injectPlatformEnvironment(controller);
                },
                onLoadStop: (controller, url) async {
                  await _enableSkipFrontendSplash(controller);
                },
                onUpdateVisitedHistory: (controller, url, isReload) {
                  _syncCurrentRoute(url);
                },
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  if (!navigationAction.isForMainFrame) {
                    return NavigationActionPolicy.ALLOW;
                  }

                  final url = navigationAction.request.url;
                  if (isExternalSchemeUrl(url)) {
                    _markReloadMainOnReturn();
                    await openExternalScheme(url!);
                    return NavigationActionPolicy.CANCEL;
                  }

                  if (_shouldOpenInSubPage(url)) {
                    await _handleExternalUrl(url!);
                    return NavigationActionPolicy.CANCEL;
                  }

                  return NavigationActionPolicy.ALLOW;
                },
                onCreateWindow: (controller, createWindowAction) async {
                  // if (!createWindowAction.isForMainFrame) {
                  //   return false;
                  // }

                  final url = createWindowAction.request.url;
                  if (isExternalSchemeUrl(url)) {
                    _markReloadMainOnReturn();
                    await openExternalScheme(url!);
                    return false;
                  }

                  if (mounted && isBrowserHintUrl(url)) {
                    final action = await getBrowserHintAction(context, url!);
                    if (action == BrowserHintAction.browser) {
                      _markReloadMainOnReturn();
                      await openSystemBrowser(url);
                      return false;
                    }
                  }

                  if (mounted) {
                    if (_isDepositRoute && isWebUrl(url)) {
                      if (!context.mounted) {
                        return false;
                      }

                      final action = await showDepositLinkPrompt(context);
                      if (action == DepositLinkAction.browser) {
                        _markReloadMainOnReturn();
                        await openSystemBrowser(url!);
                        return false;
                      }
                    }

                    await _openWindowSubPage(
                      createWindowAction.windowId,
                      url,
                      promptDepositLink: _isDepositRoute && !isWebUrl(url),
                    );
                  }
                  return true;
                },
                onProgressChanged: (controller, progress) {
                  setState(() {
                    _progress = progress / 100;
                  });
                },
              ),
              if (_progress > 0 && _progress < 1)
                LinearProgressIndicator(
                  value: _progress,
                  minHeight: 2,
                  backgroundColor: Colors.transparent,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashView extends StatefulWidget {
  const SplashView({
    super.key,
    required this.packageInfoFuture,
  });

  final Future<PackageInfo> packageInfoFuture;

  @override
  State<SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<SplashView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFFF8FAFC),
              Color(0xFFEFFDF8),
              Color(0xFFF8FAFC),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            child: Column(
              children: <Widget>[
                const Spacer(flex: 3),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    final pulse = 0.96 + (_controller.value * 0.08);
                    return Transform.scale(
                      scale: pulse > 1 ? 2 - pulse : pulse,
                      child: child,
                    );
                  },
                  child: Container(
                    width: 92,
                    height: 92,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x220F766E),
                          blurRadius: 34,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: <Widget>[
                        AnimatedBuilder(
                          animation: _controller,
                          builder: (context, child) {
                            return Transform.rotate(
                              angle: _controller.value * 6.283185307179586,
                              child: child,
                            );
                          },
                          child: const SizedBox(
                            width: 70,
                            height: 70,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF0F766E),
                              ),
                              backgroundColor: Color(0xFFE2E8F0),
                            ),
                          ),
                        ),
                        const Text(
                          '盛',
                          style: TextStyle(
                            fontSize: 32,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                const Text(
                  AppConfig.appName,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  '正在连接...',
                  style: TextStyle(
                    fontSize: 15,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 28),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return LinearProgressIndicator(
                        value: 0.35 + (_controller.value * 0.45),
                        minHeight: 5,
                        backgroundColor: const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF0F766E),
                        ),
                      );
                    },
                  ),
                ),
                const Spacer(flex: 4),
                const Text(
                  '首次启动会自动选择最快可用线路',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 12),
                FutureBuilder<PackageInfo>(
                  future: widget.packageInfoFuture,
                  builder: (context, snapshot) {
                    final versionText = snapshot.hasData
                        ? '版本 v${snapshot.requireData.version}'
                        : '版本 --';
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Text(
                        versionText,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ResolveErrorView extends StatelessWidget {
  const ResolveErrorView({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        maintainBottomViewPadding: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(
                  Icons.wifi_off_rounded,
                  size: 44,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(height: 16),
                const Text(
                  '连接失败',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('重试'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'dart:io';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

String get appPlatformName {
  if (Platform.isIOS) {
    return 'ios';
  }

  if (Platform.isAndroid) {
    return 'android';
  }

  return 'unknown';
}

String get appBrowserUserAgent {
  if (Platform.isIOS) {
    return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
        'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
        'Mobile/15E148 Safari/604.1';
  }

  if (Platform.isAndroid) {
    return 'Mozilla/5.0 (Linux; Android 13; Mobile) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/120.0.0.0 Mobile Safari/537.36';
  }

  return '';
}

UserScript buildPlatformUserScript() {
  return UserScript(
    source: platformEnvironmentScript,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );
}

UserScript buildSkipFrontendSplashUserScript() {
  return UserScript(
    source: skipFrontendSplashScript,
    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
  );
}

String get platformEnvironmentScript {
  final platform = appPlatformName;
  return '''
window.__SD_APP_ENV__ = Object.assign({}, window.__SD_APP_ENV__, {
  platform: '$platform',
  isIOS: ${platform == 'ios'},
  isAndroid: ${platform == 'android'}
});
window.sdAppPlatform = '$platform';
''';
}

const String skipFrontendSplashScript = '''
window.__SD_APP_SKIP_SPLASH__ = true;
''';

Future<void> injectPlatformEnvironment(InAppWebViewController controller) {
  return controller.evaluateJavascript(source: platformEnvironmentScript);
}

Future<void> injectSkipFrontendSplash(InAppWebViewController controller) {
  return controller.evaluateJavascript(source: skipFrontendSplashScript);
}

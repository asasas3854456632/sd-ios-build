import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

bool isWebUrl(WebUri? url) {
  if (url == null) {
    return false;
  }

  final uri = Uri.tryParse(url.toString().trim());
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}

bool isExternalSchemeUrl(WebUri? url) {
  if (url == null) {
    return false;
  }

  final rawUrl = url.toString().trim();
  if (rawUrl.isEmpty) {
    return false;
  }

  final uri = Uri.tryParse(rawUrl);
  if (uri == null || uri.scheme.isEmpty) {
    return false;
  }

  return uri.scheme != 'http' &&
      uri.scheme != 'https' &&
      uri.scheme != 'about' &&
      uri.scheme != 'data' &&
      uri.scheme != 'javascript';
}

Future<bool> openExternalScheme(WebUri url) async {
  try {
    return launchUrl(
      Uri.parse(url.toString()),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    return false;
  }
}

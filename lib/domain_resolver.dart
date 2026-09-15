import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class DomainResolver {
  DomainResolver({
    http.Client? client,
    Duration timeout = const Duration(seconds: 8),
  })  : _client = client ?? http.Client(),
        _timeout = timeout;

  static const String _cacheKey = 'active_webview_domain';

  final http.Client _client;
  final Duration _timeout;

  Future<String> resolve() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedDomain = prefs.getString(_cacheKey);

    if (cachedDomain != null && await _canLoadIcon(cachedDomain)) {
      return _normalizeDomain(cachedDomain);
    }

    for (final apiUrl in AppConfig.apiDomainUrls) {
      final apiDomains = await _fetchDomainList(apiUrl);
      final apiDomain = await _firstAvailableDomain(apiDomains);
      if (apiDomain != null) {
        await _cacheDomain(prefs, apiDomain);
        return apiDomain;
      }
    }

    final giteeDomains = await _fetchDomainList(AppConfig.domainUpdateJsonUrl);
    final giteeDomain = await _firstAvailableDomain(giteeDomains);
    if (giteeDomain != null) {
      await _cacheDomain(prefs, giteeDomain);
      return giteeDomain;
    }

    throw const DomainResolveException('没有找到可用域名');
  }

  Future<void> clearCachedDomain() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }

  Future<void> _cacheDomain(SharedPreferences prefs, String domain) {
    return prefs.setString(_cacheKey, _normalizeDomain(domain));
  }

  Future<String?> _firstAvailableDomain(List<String> domains) async {
    for (final domain in domains) {
      if (await _canLoadIcon(domain)) {
        return _normalizeDomain(domain);
      }
    }
    return null;
  }

  Future<bool> _canLoadIcon(String domain) async {
    final iconUri = _buildIconUri(domain);
    if (iconUri == null) {
      return false;
    }

    try {
      final response = await _client.get(iconUri).timeout(_timeout);
      return response.statusCode >= 200 &&
          response.statusCode < 400 &&
          response.bodyBytes.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<List<String>> _fetchDomainList(String url) async {
    if (url.trim().isEmpty) {
      return const <String>[];
    }

    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) {
      return const <String>[];
    }

    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 400) {
        return const <String>[];
      }
      return _parseDomainList(response.body);
    } catch (_) {
      return const <String>[];
    }
  }

  List<String> _parseDomainList(String body) {
    try {
      final decoded = jsonDecode(body);
      final values = switch (decoded) {
        List<dynamic> list => list,
        Map<String, dynamic> map => map['domains'] ??
            map['data'] ??
            map['list'] ??
            map['urls'] ??
            const <dynamic>[],
        _ => const <dynamic>[],
      };

      if (values is! List<dynamic>) {
        return const <String>[];
      }

      return values
          .whereType<String>()
          .map(_normalizeDomain)
          .where((domain) => domain.isNotEmpty)
          .toSet()
          .toList(growable: false);
    } catch (_) {
      return const <String>[];
    }
  }

  Uri? _buildIconUri(String domain) {
    final normalized = _normalizeDomain(domain);
    if (normalized.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return uri.resolve(AppConfig.domainIconPath);
  }

  String _normalizeDomain(String domain) {
    final trimmed = domain.trim();
    if (trimmed.isEmpty) {
      return '';
    }

    final withScheme = trimmed.startsWith(RegExp(r'https?://'))
        ? trimmed
        : 'https://$trimmed';
    return withScheme.endsWith('/')
        ? withScheme.substring(0, withScheme.length - 1)
        : withScheme;
  }
}

class DomainResolveException implements Exception {
  const DomainResolveException(this.message);

  final String message;

  @override
  String toString() => message;
}

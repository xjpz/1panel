import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

class AppUserAgent {
  AppUserAgent._();

  static const productToken = '1Panel-Pro';
  static const widgetProductToken = '1Panel-Pro-Widget';
  static const displayName = '1Panel Pro';
  static const _fallbackVersion = '1.0.0';

  static Future<String>? _cached;
  static Future<String>? _widgetCached;

  static Future<String> get value =>
      _cached ??= _build(productToken: productToken);

  static Future<String> get widgetValue => _widgetCached ??= _build(
    productToken: widgetProductToken,
    platformLabel: 'iOS Widget',
  );

  static Future<String> _build({
    required String productToken,
    String? platformLabel,
  }) async {
    final version = await _version();
    final platform = platformLabel ?? _platformLabel();
    final osVersion = _commentValue(Platform.operatingSystemVersion);

    return '$productToken/$version ($platform; $osVersion)';
  }

  static Future<String> _version() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final version = _productValue(info.version);
      final buildNumber = _productValue(info.buildNumber);
      if (version.isEmpty) return _fallbackVersion;
      if (buildNumber.isEmpty) return version;
      return '$version+$buildNumber';
    } catch (_) {
      return _fallbackVersion;
    }
  }

  static String _platformLabel() {
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    if (Platform.isFuchsia) return 'Fuchsia';
    return 'Unknown';
  }

  static String _productValue(String value) {
    return value.trim().replaceAll(RegExp(r'[^A-Za-z0-9._+-]'), '_');
  }

  static String _commentValue(String value) {
    final normalized = value
        .replaceAll(RegExp(r'[\r\n()]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return normalized.isEmpty ? 'Unknown OS' : normalized;
  }
}

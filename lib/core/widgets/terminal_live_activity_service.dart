import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TerminalLiveActivityService {
  const TerminalLiveActivityService._();

  static const MethodChannel _channel = MethodChannel(
    'mono_dash/terminal_live_activity',
  );

  static Future<bool> isSupported() async {
    if (!Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (e) {
      debugPrint('TerminalLiveActivity: isSupported failed $e');
      return false;
    }
  }

  static Future<void> start({
    required String id,
    required String title,
    required String subtitle,
    required String status,
  }) => _invoke('start', {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'status': status,
  });

  static Future<void> update({
    required String id,
    required String title,
    required String subtitle,
    required String status,
  }) => _invoke('update', {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'status': status,
  });

  static Future<void> end({
    required String id,
    required String title,
    required String subtitle,
    required String status,
  }) => _invoke('end', {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'status': status,
  });

  static Future<void> endAll() => _invoke('endAll');

  static Future<void> _invoke(
    String method, [
    Map<String, Object?> arguments = const {},
  ]) async {
    if (!Platform.isIOS) return;
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } catch (e) {
      debugPrint('TerminalLiveActivity: $method failed $e');
    }
  }
}

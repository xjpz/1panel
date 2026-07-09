import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/presentation/features/settings/providers/app_settings_provider.dart';

void main() {
  group('AppIconVariant', () {
    test('default keeps the primary icon so the system auto-switches it', () {
      expect(
        AppIconVariant.defaultIcon.effectiveAlternateIconName(Brightness.light),
        isNull,
      );
      expect(
        AppIconVariant.defaultIcon.effectiveAlternateIconName(Brightness.dark),
        isNull,
      );
    });

    test('dark forces the dark alternate regardless of brightness', () {
      expect(
        AppIconVariant.dark.effectiveAlternateIconName(Brightness.light),
        AppIconVariant.dark.alternateIconName,
      );
      expect(
        AppIconVariant.dark.effectiveAlternateIconName(Brightness.dark),
        AppIconVariant.dark.alternateIconName,
      );
    });

    test('legacy "adaptive" preference falls back to the default icon', () {
      expect(AppIconVariant.fromName('adaptive'), AppIconVariant.defaultIcon);
    });
  });
}

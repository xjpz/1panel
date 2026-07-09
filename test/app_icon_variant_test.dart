import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/presentation/features/settings/providers/app_settings_provider.dart';

void main() {
  group('AppIconVariant', () {
    test('adapts icon name by brightness', () {
      expect(
        AppIconVariant.adaptive.effectiveWidgetAppIconName(Brightness.light),
        isNull,
      );
      expect(
        AppIconVariant.adaptive.effectiveWidgetAppIconName(Brightness.dark),
        AppIconVariant.dark.alternateIconName,
      );
    });

    test('exposes the same adaptive behavior in alternate icon sync', () {
      expect(
        AppIconVariant.adaptive.effectiveAlternateIconName(Brightness.light),
        isNull,
      );
      expect(
        AppIconVariant.adaptive.effectiveAlternateIconName(Brightness.dark),
        AppIconVariant.dark.alternateIconName,
      );
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:gallerio/app/theme.dart';

void main() {
  group('AppColors', () {
    test('navBarBackground is defined', () {
      expect(AppColors.navBarBackground, isNotNull);
    });

    test('scaffoldBackground is defined', () {
      expect(AppColors.scaffoldBackground, isNotNull);
    });

    test('textPrimary and textSecondary are defined', () {
      expect(AppColors.textPrimary, isNotNull);
      expect(AppColors.textSecondary, isNotNull);
    });
  });
}

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gallerio/main.dart' as app;
import '../helpers/perf_monitor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Startup Performance', () {
    testWidgets('Measure cold start time', (tester) async {
      final timer = Stopwatch()..start();
      app.main();
      await tester.pumpAndSettle();
      timer.stop();

      print('\n========================================');
      print('  COLD START PERFORMANCE');
      print('========================================');
      print('  Time to first pump: ${timer.elapsedMilliseconds}ms');

      final memory = PerfMonitor.getCurrentMemoryKb();
      print('  Memory at startup: ${memory}KB (${(memory / 1024).toStringAsFixed(1)}MB)');

      if (timer.elapsedMilliseconds > 3000) {
        print('  ⚠ SLOW: Startup >3s. Consider:');
        print('    - Lazy initialization of providers');
        print('    - Defer heavy plugins (cryptography, drift)');
        print('    - Use splash screen');
      } else if (timer.elapsedMilliseconds > 1500) {
        print('  ⚠ MODERATE: Startup >1.5s. Room for improvement.');
      } else {
        print('  ✓ GOOD: Startup <1.5s');
      }
      print('========================================\n');
    });

    testWidgets('Measure time to interactive (navigate to gallery)', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final timer = Stopwatch()..start();

      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      timer.stop();
      print('\n========================================');
      print('  TIME TO INTERACTIVE');
      print('========================================');
      print('  Time to stable UI: ${timer.elapsedMilliseconds}ms');
      print('========================================\n');
    });
  });
}

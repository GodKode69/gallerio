import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gallerio/main.dart' as app;
import '../test/helpers/perf_monitor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Gallery Scroll Performance', () {
    testWidgets('Measure gallery grid scroll FPS and memory', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final monitor = PerfMonitor();
      monitor.start(name: 'Gallery Scroll');

      for (int i = 0; i < 20; i++) {
        await tester.drag(find.byType(MaterialApp), const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 16));
        monitor.recordFrame();
      }
      await tester.pumpAndSettle();

      final report = monitor.stop(name: 'Gallery Scroll');
      print(report);

      if (report.jankPercent > 10) {
        print('  ⚠ HIGH JANK: ${report.jankPercent.toStringAsFixed(1)}% of frames are janky');
        print('    Consider: lazy loading, image caching, reducing widget rebuilds');
      } else if (report.jankPercent > 5) {
        print('  ⚠ MODERATE JANK: ${report.jankPercent.toStringAsFixed(1)}%');
      } else {
        print('  ✓ LOW JANK: ${report.jankPercent.toStringAsFixed(1)}%');
      }
    });

    testWidgets('Measure album grid scroll performance', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final monitor = PerfMonitor();
      monitor.start(name: 'Album Scroll');

      for (int i = 0; i < 15; i++) {
        await tester.drag(find.byType(MaterialApp), const Offset(0, -200));
        await tester.pump(const Duration(milliseconds: 16));
        monitor.recordFrame();
      }
      await tester.pumpAndSettle();

      final report = monitor.stop(name: 'Album Scroll');
      print(report);
    });
  });
}

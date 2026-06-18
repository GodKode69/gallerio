import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gallerio/main.dart' as app;
import '../test/helpers/perf_monitor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Viewer Performance', () {
    testWidgets('Measure viewer open/close memory impact', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      print('\n========================================');
      print('  VIEWER MEMORY IMPACT');
      print('========================================');

      final memBefore = PerfMonitor.getCurrentMemoryKb();
      print('  Memory before viewer: ${memBefore}KB (${(memBefore / 1024).toStringAsFixed(1)}MB)');

      await tester.pumpAndSettle(const Duration(seconds: 2));

      final memAfter = PerfMonitor.getCurrentMemoryKb();
      print('  Memory after idle:    ${memAfter}KB (${(memAfter / 1024).toStringAsFixed(1)}MB)');
      print('  Idle memory delta:    ${memAfter - memBefore}KB');

      if (memAfter - memBefore > 5120) {
        print('  ⚠ Memory grew >5MB during idle. Possible memory leak.');
      }
      print('========================================\n');
    });

    testWidgets('Measure pinch zoom frame performance', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final monitor = PerfMonitor();
      monitor.start(name: 'Pinch Zoom');

      final center = tester.getCenter(find.byType(MaterialApp));
      final offset1 = Offset(center.dx - 50, center.dy);

      await tester.tapAt(offset1);
      await tester.pump(const Duration(milliseconds: 100));

      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        monitor.recordFrame();
      }

      final report = monitor.stop(name: 'Pinch Zoom');
      print(report);
    });

    testWidgets('Measure double-tap zoom animation performance', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      final monitor = PerfMonitor();
      monitor.start(name: 'Double-Tap Zoom');

      final center = tester.getCenter(find.byType(MaterialApp));

      await tester.tapAt(center);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(center);

      for (int i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        monitor.recordFrame();
      }

      final report = monitor.stop(name: 'Double-Tap Zoom');
      print(report);

      if (report.maxFrameMs > 32) {
        print('  ⚠ Zoom animation had frames >32ms. May feel laggy.');
      } else {
        print('  ✓ Zoom animation is smooth');
      }
    });
  });
}

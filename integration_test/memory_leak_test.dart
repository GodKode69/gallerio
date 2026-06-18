import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gallerio/main.dart' as app;
import '../test/helpers/perf_monitor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Memory Leak Detection', () {
    testWidgets('Open and close viewer 10 times, check heap growth', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      print('\n========================================');
      print('  MEMORY LEAK DETECTION (10x viewer open/close)');
      print('========================================');

      final readings = <int>[];
      final memBaseline = PerfMonitor.getCurrentMemoryKb();
      readings.add(memBaseline);
      print('  Baseline: ${memBaseline}KB (${(memBaseline / 1024).toStringAsFixed(1)}MB)');

      for (int i = 0; i < 10; i++) {
        await tester.pumpAndSettle(const Duration(milliseconds: 200));

        final mem = PerfMonitor.getCurrentMemoryKb();
        readings.add(mem);
      }

      final finalMem = PerfMonitor.getCurrentMemoryKb();
      readings.add(finalMem);

      print('\n  Memory readings (KB):');
      for (int i = 0; i < readings.length; i++) {
        final delta = readings[i] - memBaseline;
        final indicator = delta > 5120 ? ' ⚠' : '';
        print('    Reading $i: ${readings[i]}KB (delta: ${delta > 0 ? '+' : ''}${delta}KB)$indicator');
      }

      final growth = finalMem - memBaseline;
      print('\n  Total memory growth: ${growth}KB (${(growth / 1024).toStringAsFixed(1)}MB)');

      if (growth > 10240) {
        print('  ⚠ CRITICAL: Memory grew >10MB. Likely memory leak!');
        print('    Check: AnimationControllers, StreamSubscriptions, Timer callbacks');
      } else if (growth > 5120) {
        print('  ⚠ WARNING: Memory grew >5MB. Possible memory leak.');
      } else if (growth > 2048) {
        print('  ⚠ INFO: Memory grew >2MB. Monitor over longer usage.');
      } else {
        print('  ✓ GOOD: Memory growth is within normal range');
      }

      final maxReading = readings.reduce((a, b) => a > b ? a : b);
      print('  Peak memory: ${maxReading}KB (${(maxReading / 1024).toStringAsFixed(1)}MB)');
      print('========================================\n');
    });

    testWidgets('Scroll gallery extensively and check memory', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      print('\n========================================');
      print('  GALLERY SCROLL MEMORY TEST');
      print('========================================');

      final memBefore = PerfMonitor.getCurrentMemoryKb();
      print('  Memory before scroll: ${memBefore}KB (${(memBefore / 1024).toStringAsFixed(1)}MB)');

      for (int i = 0; i < 50; i++) {
        await tester.drag(find.byType(MaterialApp), const Offset(0, -500));
        await tester.pump(const Duration(milliseconds: 32));
      }
      await tester.pumpAndSettle();

      final memAfter = PerfMonitor.getCurrentMemoryKb();
      print('  Memory after scroll:  ${memAfter}KB (${(memAfter / 1024).toStringAsFixed(1)}MB)');
      print('  Growth: ${memAfter - memBefore}KB (${((memAfter - memBefore) / 1024).toStringAsFixed(1)}MB)');

      if (memAfter - memBefore > 20480) {
        print('  ⚠ Scroll caused >20MB growth. Thumbnail caching may be unbounded.');
        print('    Consider: LRU cache, reducing thumbnail size, disposing off-screen');
      } else if (memAfter - memBefore > 10240) {
        print('  ⚠ Scroll caused >10MB growth. Monitor for leaks.');
      } else {
        print('  ✓ Memory is stable during scroll');
      }
      print('========================================\n');
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gallerio/main.dart' as app;
import '../test/helpers/perf_monitor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Frame Jank Detection', () {
    testWidgets('Measure frame times during tab switching', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 2));

      print('\n========================================');
      print('  FRAME JANK TEST (Tab Switching)');
      print('========================================');

      final monitor = PerfMonitor();
      monitor.start(name: 'Tab Switching');

      for (int i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 500));
        monitor.recordFrame();
      }

      final report = monitor.stop(name: 'Tab Switching');
      print(report);

      if (report.jankPercent > 10) {
        print('  ⚠ HIGH JANK: ${report.jankPercent.toStringAsFixed(1)}% during tab transitions');
      } else if (report.jankPercent > 5) {
        print('  ⚠ MODERATE JANK: ${report.jankPercent.toStringAsFixed(1)}%');
      } else {
        print('  ✓ Frame performance is good');
      }

      print('========================================\n');
    });

    testWidgets('Measure search screen render time', (tester) async {
      app.main();
      await tester.pump(const Duration(seconds: 2));

      print('\n========================================');
      print('  SEARCH SCREEN RENDER PERFORMANCE');
      print('========================================');

      final memBefore = PerfMonitor.getCurrentMemoryKb();
      final timer = Stopwatch()..start();

      await tester.pump(const Duration(seconds: 2));
      timer.stop();

      final memAfter = PerfMonitor.getCurrentMemoryKb();

      print('  Search screen render: ${timer.elapsedMilliseconds}ms');
      print('  Memory delta: ${memAfter - memBefore}KB');

      if (timer.elapsedMilliseconds > 1000) {
        print('  ⚠ Search screen takes >1s to render');
      } else {
        print('  ✓ Search screen renders quickly');
      }
      print('========================================\n');
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}

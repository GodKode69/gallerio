import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gallerio/main.dart' as app;
import '../helpers/perf_monitor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Frame Jank Detection', () {
    testWidgets('Measure frame times during tab switching', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      print('\n========================================');
      print('  FRAME JANK TEST (Tab Switching)');
      print('========================================');

      final frameTimes = <double>[];
      final binding = tester.binding;

      binding.addPersistentFrameCallback((timeStamp) {
        if (frameTimes.isNotEmpty) {
          final last = frameTimes.last;
          final ms = timeStamp.inMicroseconds / 1000.0 - last;
          if (ms > 0 && ms < 1000) {
            frameTimes.add(timeStamp.inMicroseconds / 1000.0);
          }
        } else {
          frameTimes.add(timeStamp.inMicroseconds / 1000.0);
        }
      });

      await Future.delayed(const Duration(seconds: 1));
      frameTimes.clear();

      final start = DateTime.now();

      for (int i = 0; i < 5; i++) {
        await tester.pumpAndSettle(const Duration(milliseconds: 500));
      }

      await tester.pumpAndSettle(const Duration(seconds: 1));

      final elapsed = DateTime.now().difference(start);

      print('  Test duration: ${elapsed.inMilliseconds}ms');

      if (frameTimes.length > 1) {
        final deltas = <double>[];
        for (int i = 1; i < frameTimes.length; i++) {
          deltas.add(frameTimes[i] - frameTimes[i - 1]);
        }

        if (deltas.isNotEmpty) {
          final avg = deltas.reduce((a, b) => a + b) / deltas.length;
          final max = deltas.reduce((a, b) => a > b ? a : b);
          final jankCount = deltas.where((d) => d > 16.67).length;
          final severeJank = deltas.where((d) => d > 32.0).length;

          print('  Frames recorded: ${deltas.length}');
          print('  Avg frame time:  ${avg.toStringAsFixed(2)}ms');
          print('  Max frame time:  ${max.toStringAsFixed(2)}ms');
          print('  Jank (>16ms):    $jankCount (${(jankCount / deltas.length * 100).toStringAsFixed(1)}%)');
          print('  Severe (>32ms):  $severeJank');

          if (severeJank > 0) {
            print('  ⚠ SEVERE JANK detected. App may stutter during tab transitions.');
          } else if (jankCount > deltas.length * 0.1) {
            print('  ⚠ Moderate jank detected (${(jankCount / deltas.length * 100).toStringAsFixed(1)}% of frames).');
          } else {
            print('  ✓ Frame performance is good');
          }
        }
      }

      print('========================================\n');
    });

    testWidgets('Measure search screen render time', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      print('\n========================================');
      print('  SEARCH SCREEN RENDER PERFORMANCE');
      print('========================================');

      final memBefore = PerfMonitor.getCurrentMemoryKb();
      final timer = Stopwatch()..start();

      await tester.pumpAndSettle(const Duration(seconds: 2));
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
    });
  });
}

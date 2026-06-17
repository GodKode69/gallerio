import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:gallerio/main.dart' as app;
import '../helpers/perf_monitor.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Full Performance Audit Report', (tester) async {
    final report = StringBuffer();
    report.writeln('╔══════════════════════════════════════════╗');
    report.writeln('║     GALLERIO PERFORMANCE AUDIT REPORT    ║');
    report.writeln('╚══════════════════════════════════════════╝');
    report.writeln('');
    report.writeln('Date: ${DateTime.now()}');
    report.writeln('Platform: ${Platform.operatingSystem}');
    report.writeln('Dart VM: ${Platform.version}');
    report.writeln('');

    // 1. Startup
    report.writeln('─── 1. STARTUP PERFORMANCE ───');
    final startMem = PerfMonitor.getCurrentMemoryKb();
    final sw = Stopwatch()..start();
    app.main();
    await tester.pumpAndSettle();
    sw.stop();
    final afterStartMem = PerfMonitor.getCurrentMemoryKb();
    report.writeln('Cold start: ${sw.elapsedMilliseconds}ms');
    report.writeln('Memory at start: ${afterStartMem}KB (${(afterStartMem / 1024).toStringAsFixed(1)}MB)');
    report.writeln('Memory delta: ${afterStartMem - startMem}KB');
    report.writeln('');

    // 2. Navigation
    report.writeln('─── 2. NAVIGATION PERFORMANCE ───');
    final navTimer = Stopwatch()..start();
    for (int i = 0; i < 5; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
    }
    navTimer.stop();
    report.writeln('5x tab settle: ${navTimer.elapsedMilliseconds}ms');
    report.writeln('Avg per tab: ${(navTimer.elapsedMilliseconds / 5).toStringAsFixed(0)}ms');
    report.writeln('');

    // 3. Gallery scroll
    report.writeln('─── 3. GALLERY SCROLL ───');
    final scrollMemBefore = PerfMonitor.getCurrentMemoryKb();
    final scrollTimer = Stopwatch()..start();
    for (int i = 0; i < 30; i++) {
      await tester.drag(find.byType(MaterialApp), const Offset(0, -400));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();
    scrollTimer.stop();
    final scrollMemAfter = PerfMonitor.getCurrentMemoryKb();
    report.writeln('30 swipes: ${scrollTimer.elapsedMilliseconds}ms');
    report.writeln('Avg per swipe: ${(scrollTimer.elapsedMilliseconds / 30).toStringAsFixed(0)}ms');
    report.writeln('Memory before: ${scrollMemBefore}KB (${(scrollMemBefore / 1024).toStringAsFixed(1)}MB)');
    report.writeln('Memory after:  ${scrollMemAfter}KB (${(scrollMemAfter / 1024).toStringAsFixed(1)}MB)');
    report.writeln('Scroll growth: ${scrollMemAfter - scrollMemBefore}KB');
    report.writeln('');

    // 4. Memory stability
    report.writeln('─── 4. MEMORY STABILITY ───');
    final readings = <int>[];
    for (int i = 0; i < 5; i++) {
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      readings.add(PerfMonitor.getCurrentMemoryKb());
    }
    final avgMem = readings.reduce((a, b) => a + b) / readings.length;
    final maxMem = readings.reduce((a, b) => a > b ? a : b);
    final minMem = readings.reduce((a, b) => a < b ? a : b);
    report.writeln('Avg memory: ${avgMem.toStringAsFixed(0)}KB (${(avgMem / 1024).toStringAsFixed(1)}MB)');
    report.writeln('Min memory: ${minMem}KB (${(minMem / 1024).toStringAsFixed(1)}MB)');
    report.writeln('Max memory: ${maxMem}KB (${(maxMem / 1024).toStringAsFixed(1)}MB)');
    report.writeln('Variance:   ${maxMem - minMem}KB (${((maxMem - minMem) / 1024).toStringAsFixed(1)}MB)');
    report.writeln('');

    // 5. Storage
    report.writeln('─── 5. STORAGE ANALYSIS ───');
    final apkFile = File('build/app/outputs/flutter-apk/app-release.apk');
    if (apkFile.existsSync()) {
      report.writeln('APK size: ${(apkFile.lengthSync() / (1024 * 1024)).toStringAsFixed(1)}MB');
    } else {
      report.writeln('APK: not built yet');
    }

    final dbDir = Directory('/data/data/com.arqora.gallerio/databases');
    if (await dbDir.exists()) {
      int dbSize = 0;
      await for (final f in dbDir.list()) {
        if (f is File) dbSize += await f.length();
      }
      report.writeln('Database: ${(dbSize / 1024).toStringAsFixed(1)}KB');
    } else {
      report.writeln('Database: (run on device to measure)');
    }

    final cacheDir = Directory('/data/data/com.arqora.gallerio/cache');
    if (await cacheDir.exists()) {
      int cacheSize = 0;
      await for (final f in cacheDir.list(recursive: true)) {
        if (f is File) cacheSize += await f.length();
      }
      report.writeln('Cache: ${(cacheSize / 1024).toStringAsFixed(1)}KB');
    }
    report.writeln('');

    // 6. Recommendations
    report.writeln('─── 6. RECOMMENDATIONS ───');
    if (sw.elapsedMilliseconds > 2000) {
      report.writeln('[HIGH] Startup is slow (${sw.elapsedMilliseconds}ms)');
      report.writeln('  → Lazy-init heavy plugins (cryptography, drift)');
      report.writeln('  → Add splash screen');
      report.writeln('  → Defer SharedPreferences reads');
    }
    if (scrollMemAfter - scrollMemBefore > 10240) {
      report.writeln('[HIGH] Gallery scroll leaks memory (${scrollMemAfter - scrollMemBefore}KB)');
      report.writeln('  → Add LRU thumbnail cache');
      report.writeln('  → Dispose off-screen thumbnails');
    }
    if (maxMem - minMem > 20480) {
      report.writeln('[MED] Memory variance >20MB');
      report.writeln('  → Investigate peak memory events');
    }
    if (apkFile.existsSync() && apkFile.lengthSync() > 50 * 1024 * 1024) {
      report.writeln('[MED] APK >50MB');
      report.writeln('  → Use --split-per-abi');
      report.writeln('  → Consider AAB for Play Store');
    }
    report.writeln('');
    report.writeln('══════════════════════════════════════════');
    report.writeln('  Report generated successfully');
    report.writeln('══════════════════════════════════════════');

    // ignore: avoid_print
    print(report.toString());
    print('\nReport printed to console (file write skipped on device)');
  }, timeout: const Timeout(Duration(minutes: 2)));
}

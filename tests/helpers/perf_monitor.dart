import 'dart:async';
import 'dart:io';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

class PerfReport {
  final String name;
  final Duration totalDuration;
  final int frameCount;
  final int jankFrameCount;
  final double avgFrameMs;
  final double maxFrameMs;
  final int startMemoryKb;
  final int peakMemoryKb;
  final int endMemoryKb;

  const PerfReport({
    required this.name,
    required this.totalDuration,
    required this.frameCount,
    required this.jankFrameCount,
    required this.avgFrameMs,
    required this.maxFrameMs,
    required this.startMemoryKb,
    required this.peakMemoryKb,
    required this.endMemoryKb,
  });

  double get jankPercent => frameCount > 0 ? (jankFrameCount / frameCount * 100) : 0;
  int get memoryDeltaKb => endMemoryKb - startMemoryKb;

  @override
  String toString() {
    final buf = StringBuffer();
    buf.writeln('=== $name ===');
    buf.writeln('Duration:       ${totalDuration.inMilliseconds}ms');
    buf.writeln('Frames:         $frameCount');
    buf.writeln('Jank frames:    $jankFrameCount (${jankPercent.toStringAsFixed(1)}%)');
    buf.writeln('Avg frame:      ${avgFrameMs.toStringAsFixed(2)}ms');
    buf.writeln('Max frame:      ${maxFrameMs.toStringAsFixed(2)}ms');
    buf.writeln('Start memory:   ${startMemoryKb}KB (${(startMemoryKb / 1024).toStringAsFixed(1)}MB)');
    buf.writeln('Peak memory:    ${peakMemoryKb}KB (${(peakMemoryKb / 1024).toStringAsFixed(1)}MB)');
    buf.writeln('End memory:     ${endMemoryKb}KB (${(endMemoryKb / 1024).toStringAsFixed(1)}MB)');
    buf.writeln('Memory delta:   ${memoryDeltaKb}KB (${(memoryDeltaKb / 1024).toStringAsFixed(1)}MB)');
    return buf.toString();
  }
}

class PerfMonitor {
  final Stopwatch _stopwatch = Stopwatch();
  final List<double> _frameTimes = [];
  int _jankFrameCount = 0;
  int _startMemoryKb = 0;
  int _peakMemoryKb = 0;
  bool _monitoring = false;
  DateTime? _lastFrameTimestamp;

  static const double _jankThresholdMs = 16.67;

  static int getCurrentMemoryKb() {
    try {
      final file = File('/proc/self/status');
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        for (final line in lines) {
          if (line.startsWith('VmRSS:')) {
            final parts = line.split(RegExp(r'\s+'));
            if (parts.length >= 2) return int.parse(parts[1]);
          }
        }
      }
    } catch (_) {}
    return _getMemoryFromVmStat();
  }

  static int _getMemoryFromVmStat() {
    try {
      final file = File('/proc/self/statm');
      if (file.existsSync()) {
        final content = file.readAsStringSync().trim();
        final parts = content.split(RegExp(r'\s+'));
        if (parts.isNotEmpty) {
          final pages = int.parse(parts[0]);
          return pages * 4;
        }
      }
    } catch (_) {}
    return 0;
  }

  void start({String name = 'unnamed'}) {
    _frameTimes.clear();
    _jankFrameCount = 0;
    _monitoring = true;
    _lastFrameTimestamp = null;
    _startMemoryKb = getCurrentMemoryKb();
    _peakMemoryKb = _startMemoryKb;

    SchedulerBinding.instance.addPostFrameCallback(_onFrame);

    _stopwatch.reset();
    _stopwatch.start();
  }

  void _onFrame(Duration timeStamp) {
    if (!_monitoring) return;

    final now = DateTime.now();
    if (_lastFrameTimestamp != null) {
      final frameMs = now.difference(_lastFrameTimestamp!).inMicroseconds / 1000.0;
      _frameTimes.add(frameMs);
      if (frameMs > _jankThresholdMs) _jankFrameCount++;
    }
    _lastFrameTimestamp = now;

    final currentMem = getCurrentMemoryKb();
    if (currentMem > _peakMemoryKb) _peakMemoryKb = currentMem;

    if (_monitoring) {
      SchedulerBinding.instance.addPostFrameCallback(_onFrame);
    }
  }

  void recordFrame() {
    if (!_monitoring) return;
    final currentMem = getCurrentMemoryKb();
    if (currentMem > _peakMemoryKb) _peakMemoryKb = currentMem;
  }

  PerfReport stop({String name = 'unnamed'}) {
    _stopwatch.stop();
    _monitoring = false;
    final endMemoryKb = getCurrentMemoryKb();

    final avgFrame = _frameTimes.isEmpty
        ? 0.0
        : _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
    final maxFrame = _frameTimes.isEmpty
        ? 0.0
        : _frameTimes.reduce((a, b) => a > b ? a : b);

    return PerfReport(
      name: name,
      totalDuration: _stopwatch.elapsed,
      frameCount: _frameTimes.length,
      jankFrameCount: _jankFrameCount,
      avgFrameMs: avgFrame,
      maxFrameMs: maxFrame,
      startMemoryKb: _startMemoryKb,
      peakMemoryKb: _peakMemoryKb,
      endMemoryKb: endMemoryKb,
    );
  }
}

class StartupTimer {
  final Stopwatch _sw = Stopwatch();
  DateTime? _appStart;
  DateTime? _firstFrame;

  void markAppStart() {
    _appStart = DateTime.now();
    _sw.start();
  }

  void markFirstFrame() {
    _firstFrame = DateTime.now();
    _sw.stop();
  }

  Duration get coldStartTime {
    if (_appStart == null || _firstFrame == null) return Duration.zero;
    return _firstFrame!.difference(_appStart!);
  }

  Duration get measuredTime => _sw.elapsed;
}

class FrameTracker {
  final List<double> _frameTimes = [];
  bool _tracking = false;
  int _jankCount = 0;

  static const double _jankThresholdMs = 16.67;
  static const double _severeJankThresholdMs = 32.0;

  int get totalFrames => _frameTimes.length;
  int get jankFrames => _jankCount;
  int get severeJankFrames =>
      _frameTimes.where((f) => f > _severeJankThresholdMs).length;
  double get jankPercent =>
      totalFrames > 0 ? (_jankCount / totalFrames * 100) : 0;
  double get avgFrameMs =>
      _frameTimes.isEmpty ? 0 : _frameTimes.reduce((a, b) => a + b) / _frameTimes.length;
  double get maxFrameMs =>
      _frameTimes.isEmpty ? 0 : _frameTimes.reduce((a, b) => a > b ? a : b);

  void startTracking() {
    _tracking = true;
    _frameTimes.clear();
    _jankCount = 0;
  }

  void stopTracking() {
    _tracking = false;
  }

  void recordFrame(double frameMs) {
    if (!_tracking) return;
    _frameTimes.add(frameMs);
    if (frameMs > _jankThresholdMs) _jankCount++;
  }

  Map<String, dynamic> getReport() {
    return {
      'total_frames': totalFrames,
      'jank_frames': _jankCount,
      'severe_jank_frames': severeJankFrames,
      'jank_percent': double.parse(jankPercent.toStringAsFixed(1)),
      'avg_frame_ms': double.parse(avgFrameMs.toStringAsFixed(2)),
      'max_frame_ms': double.parse(maxFrameMs.toStringAsFixed(2)),
    };
  }
}

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('APK Size Analysis', () {
    test('APK size breakdown and report', () async {
      final apkFile = File('build/app/outputs/flutter-apk/app-release.apk');
      if (!apkFile.existsSync()) {
        print('⚠ APK not found at ${apkFile.path}. Run: flutter build apk --release');
        return;
      }

      final totalSize = apkFile.lengthSync();
      print('\n========================================');
      print('  APK SIZE ANALYSIS');
      print('========================================');
      print('Total APK size: ${_formatSize(totalSize)}');

      final unzipResult = await Process.run('unzip', ['-l', apkFile.path]);
      if (unzipResult.exitCode == 0) {
        final lines = (unzipResult.stdout as String).split('\n');
        final fileSizes = <String, int>{};
        int totalUncompressed = 0;

        for (final line in lines) {
          final match = RegExp(r'(\d+)\s+(\d+:\d+)\s+(.+)').firstMatch(line);
          if (match != null) {
            final size = int.parse(match.group(1)!);
            final name = match.group(3)!.trim();
            totalUncompressed += size;

            String category;
            if (name.endsWith('.so')) {
              category = 'Native Libraries (lib/)';
            } else if (name.endsWith('.dex')) {
              category = 'DEX (Dart code)';
            } else if (name.endsWith('.arsc') || name.contains('res/')) {
              category = 'Resources';
            } else if (name.startsWith('assets/')) {
              category = 'Assets';
            } else if (name.contains('META-INF')) {
              category = 'META-INF (signatures)';
            } else {
              category = 'Other';
            }
            fileSizes[category] = (fileSizes[category] ?? 0) + size;
          }
        }

        print('\n--- Category Breakdown ---');
        final sorted = fileSizes.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        for (final entry in sorted) {
          final percent = (entry.value / totalUncompressed * 100).toStringAsFixed(1);
          print('${entry.key.padRight(28)} ${_formatSize(entry.value).padLeft(10)}  ($percent%)');
        }
        print('${'Total uncompressed'.padRight(28)} ${_formatSize(totalUncompressed).padLeft(10)}');
      }

      print('\n--- Detailed Native Libraries ---');
      final libResult = await Process.run('unzip', ['-l', apkFile.path]);
      if (libResult.exitCode == 0) {
        final lines = (libResult.stdout as String).split('\n');
        for (final line in lines) {
          if (line.contains('.so')) {
            final match = RegExp(r'(\d+)\s+\d+:\d+\s+(.+)').firstMatch(line);
            if (match != null) {
              final size = int.parse(match.group(1)!);
              final name = match.group(2)!.trim();
              print('  ${name.split('/').last.padRight(30)} ${_formatSize(size).padLeft(10)}');
            }
          }
        }
      }

      print('\n--- Size Reduction Recommendations ---');
      if (totalSize > 50 * 1024 * 1024) {
        print('  [HIGH] APK is over 50MB. Consider:');
        print('    - Split APKs by ABI (arm64-v8a, armeabi-v7a)');
        print('    - Use app bundle (AAB) instead of APK for Play Store');
        print('    - Enable R8 full mode for better shrinking');
      }
      if (totalSize > 30 * 1024 * 1024) {
        print('  [MED]  APK is over 30MB. Consider:');
        print('    - Compress images and assets');
        print('    - Remove unused native libraries');
      }
      print('  [INFO] Current: ${_formatSize(totalSize)}');
      print('========================================\n');
    }, timeout: const Timeout(Duration(seconds: 30)));
  });
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

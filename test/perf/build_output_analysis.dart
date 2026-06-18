import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Analyze build output sizes', () {
    print('\n========================================');
    print('  BUILD OUTPUT ANALYSIS');
    print('========================================');

    final outputs = [
      'build/app/outputs/flutter-apk/app-release.apk',
      'build/app/outputs/flutter-apk/app-release.apk.tmp',
    ];

    for (final path in outputs) {
      final file = File(path);
      if (file.existsSync()) {
        final size = file.lengthSync();
        print('  ${path.split('/').last.padRight(30)} ${_formatSize(size)}');
      }
    }

    final buildDir = Directory('build/app/intermediates');
    if (buildDir.existsSync()) {
      int totalDex = 0;

      final dexFiles = buildDir
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dex'))
          .toList();
      for (final f in dexFiles) {
        totalDex += f.lengthSync();
      }

      print('\n--- DEX Files ---');
      if (dexFiles.isNotEmpty) {
        for (final f in dexFiles) {
          print('  ${f.path.split('/').last.padRight(20)} ${_formatSize(f.lengthSync())}');
        }
        print('  Total DEX: ${_formatSize(totalDex)}');
      } else {
        print('  No DEX files found in build intermediates');
      }
    }

    final flutterBuildDir = Directory('build');
    if (flutterBuildDir.existsSync()) {
      int totalSize = 0;
      final files = flutterBuildDir.listSync(recursive: true).whereType<File>();
      for (final f in files) {
        totalSize += f.lengthSync();
      }
      print('\n--- Total Build Directory ---');
      print('  Total build artifacts: ${_formatSize(totalSize)}');
      print('  Total files: ${files.length}');
    }

    print('\n--- Recommendations ---');
    print('  1. Use "flutter build apk --split-per-abi" to reduce per-device APK size');
    print('  2. Use "flutter build appbundle" for Play Store (auto-splits)');
    print('  3. Verify R8 minification is working: check mapping.txt size');
    print('========================================\n');
  }, timeout: const Timeout(Duration(seconds: 10)));
}

String _formatSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

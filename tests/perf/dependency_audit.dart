import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Dependency Audit', () {
    test('Analyze pubspec.yaml dependencies for size impact', () {
      final pubspec = File('pubspec.yaml');
      if (!pubspec.existsSync()) {
        print('pubspec.yaml not found');
        return;
      }

      final content = pubspec.readAsStringSync();

      print('\n========================================');
      print('  DEPENDENCY AUDIT');
      print('========================================');

      final dependencies = <String>[];
      final devDependencies = <String>[];

      final depsMatch = RegExp(r'dependencies:\s*\n(.*?)(?=dev_dependencies:)', dotAll: true).firstMatch(content);
      if (depsMatch != null) {
        final depBlock = depsMatch.group(1)!;
        for (final m in RegExp(r'^\s{2}(\w[\w_]*):', multiLine: true).allMatches(depBlock)) {
          final name = m.group(1)!;
          if (name != 'flutter') dependencies.add(name);
        }
      }

      final devDepsMatch = RegExp(r'dev_dependencies:\s*\n(.*?)(?=flutter:)', dotAll: true).firstMatch(content);
      if (devDepsMatch != null) {
        final depBlock = devDepsMatch.group(1)!;
        for (final m in RegExp(r'^\s{2}(\w[\w_]*):', multiLine: true).allMatches(depBlock)) {
          final name = m.group(1)!;
          if (name != 'flutter') devDependencies.add(name);
        }
      }

      print('\nRuntime Dependencies (${dependencies.length}):');
      for (final dep in dependencies) {
        final weight = _getDependencyWeight(dep);
        print('  ${dep.padRight(35)} [${weight}]');
      }

      print('\nDev Dependencies (${devDependencies.length}):');
      for (final dep in devDependencies) {
        print('  $dep');
      }

      print('\n--- Heavy Dependencies Analysis ---');
      final heavy = dependencies.where((d) => _getDependencyWeight(d) == 'HEAVY').toList();
      final medium = dependencies.where((d) => _getDependencyWeight(d) == 'MEDIUM').toList();

      if (heavy.isNotEmpty) {
        print('  HEAVY (likely >1MB each):');
        for (final dep in heavy) {
          print('    $dep - ${_getReason(dep)}');
        }
      }
      if (medium.isNotEmpty) {
        print('  MEDIUM (likely 100KB-1MB):');
        for (final dep in medium) {
          print('    $dep - ${_getReason(dep)}');
        }
      }

      print('\n--- Optimization Suggestions ---');
      _printOptimizations(dependencies);

      print('\n--- Total Dependency Count ---');
      print('  Runtime: ${dependencies.length}');
      print('  Dev:     ${devDependencies.length}');
      print('  Total:   ${dependencies.length + devDependencies.length}');
      print('========================================\n');
    });

    test('Analyze pubspec.lock for actual resolved versions', () {
      final lockFile = File('pubspec.lock');
      if (!lockFile.existsSync()) {
        print('pubspec.lock not found. Run: flutter pub get');
        return;
      }

      print('\n========================================');
      print('  RESOLVED DEPENDENCY VERSIONS');
      print('========================================\n');

      final content = lockFile.readAsStringSync();
      final matches = RegExp(r'^  (\S+):\n(?:.*\n)*?    version: "(\S+)"', multiLine: true).allMatches(content);

      final resolved = <String, String>{};
      for (final match in matches) {
        resolved[match.group(1)!] = match.group(2)!;
      }

      final sorted = resolved.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
      for (final entry in sorted) {
        print('  ${entry.key.padRight(35)} ${entry.value}');
      }
      print('\n  Total resolved packages: ${resolved.length}');
      print('========================================\n');
    });
  });
}

String _getDependencyWeight(String name) {
  const heavy = {
    'cryptography', 'drift', 'sqlite3_flutter_libs', 'photo_manager',
    'local_auth', 'flutter_secure_storage', 'file_picker',
    'permission_handler', 'share_plus', 'go_router',
  };
  const medium = {
    'shimmer', 'intl', 'shared_preferences', 'path_provider',
    'riverpod_annotation', 'photo_manager_image_provider',
  };
  if (heavy.contains(name)) return 'HEAVY';
  if (medium.contains(name)) return 'MEDIUM';
  return 'LIGHT';
}

String _getReason(String name) {
  const reasons = {
    'cryptography': 'Full crypto library, only PBKDF2 used. Consider dart:crypto + manual PBKDF2',
    'drift': 'Full ORM with code generation. Consider sqflite for simpler use case',
    'sqlite3_flutter_libs': 'Bundled native SQLite (~3MB per ABI)',
    'photo_manager': 'Heavy gallery access plugin with native code',
    'local_auth': 'Biometric auth, bundles platform-specific code',
    'flutter_secure_storage': 'Encrypted shared preferences, bundles native crypto',
    'file_picker': 'Platform file picker with native UI',
    'permission_handler': 'Bundles all permission handlers (~1MB)',
    'share_plus': 'Share intent with platform code',
    'go_router': 'Declarative router, moderate size',
  };
  return reasons[name] ?? 'General dependency';
}

void _printOptimizations(List<String> dependencies) {
  final suggestions = <String>[];

  if (dependencies.contains('cryptography')) {
    suggestions.add(
      'cryptography: Only PBKDF2-HMAC-SHA256 is used. Replace with dart:crypto + manual PBKDF2 impl (~200 lines). Save: ~1-2MB',
    );
  }
  if (dependencies.contains('shimmer')) {
    suggestions.add(
      'shimmer: Only used for loading skeletons. Replace with custom AnimatedOpacity + Container shimmer (~50 lines). Save: ~50KB',
    );
  }
  if (dependencies.contains('permission_handler')) {
    suggestions.add(
      'permission_handler: Bundles ALL permission handlers. Use permission_handler_android only. Save: ~500KB',
    );
  }
  if (dependencies.contains('intl')) {
    suggestions.add(
      'intl: Used only for DateFormat. Use dart:intl directly or package:intl/DateFormat minimal import. Save: ~100KB',
    );
  }
  if (dependencies.contains('drift') && dependencies.contains('sqlite3_flutter_libs')) {
    suggestions.add(
      'drift + sqlite3_flutter_libs: Consider sqflite for simpler DB needs. Save: ~2-3MB',
    );
  }

  if (suggestions.isEmpty) {
    print('  Dependencies look lean. No major optimizations needed.');
  } else {
    for (int i = 0; i < suggestions.length; i++) {
      print('  ${i + 1}. ${suggestions[i]}');
    }
  }
}

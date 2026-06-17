import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  test('Analyze Drift database schema size', () {
    print('\n========================================');
    print('  DATABASE SCHEMA ANALYSIS');
    print('========================================');

    final generatedFile = File('lib/core/database/database.g.dart');
    if (!generatedFile.existsSync()) {
      print('  database.g.dart not found. Run: dart run build_runner build');
      return;
    }

    final lines = generatedFile.readAsLinesSync();
    print('  Generated file: ${lines.length} lines');

    final tableCount = RegExp(r'class \w+ extends DataClass').allMatches(
      generatedFile.readAsStringSync(),
    );
    print('  Data classes: ${tableCount.length}');

    final queries = RegExp(r'Future<int> ').allMatches(
      generatedFile.readAsStringSync(),
    );
    print('  Generated queries: ${queries.length}');

    final indexes = RegExp(r'Index\( ').allMatches(
      generatedFile.readAsStringSync(),
    );
    print('  Database indexes: ${indexes.length}');

    final dbFile = File('lib/core/database/database.dart');
    if (dbFile.existsSync()) {
      final dbLines = dbFile.readAsLinesSync();
      print('\n  Hand-written DB code: ${dbLines.length} lines');

      int methodCount = 0;
      for (final line in dbLines) {
        if (line.trim().startsWith('Future<') || line.trim().startsWith('Stream<')) {
          methodCount++;
        }
      }
      print('  DB methods (Future/Stream): $methodCount');
    }

    print('\n--- Optimization Notes ---');
    print('  - Use select().watch() instead of select().get() where possible');
    print('  - Add indexes on frequently queried columns');
    print('  - Use batch operations for bulk inserts/deletes');
    print('  - Consider pagination for large result sets');
    print('========================================\n');
  });

  test('Analyze ProGuard rules coverage', () {
    print('\n========================================');
    print('  PROGUARD RULES ANALYSIS');
    print('========================================');

    final proguardFile = File('android/app/proguard-rules.pro');
    if (!proguardFile.existsSync()) {
      print('  ⚠ proguard-rules.pro not found!');
      return;
    }

    final content = proguardFile.readAsStringSync();
    final keepRules = RegExp(r'-keep\s+').allMatches(content).length;
    print('  Keep rules: $keepRules');

    final sections = content.split('\n').where((l) => l.startsWith('#')).toList();
    print('  Sections:');
    for (final s in sections) {
      print('    ${s.substring(1).trim()}');
    }

    print('\n--- Coverage Check ---');
    final requiredKeeps = [
      'lazysodium',
      'bouncycastle',
      'MainActivity',
      'Drift',
    ];
    for (final req in requiredKeeps) {
      if (content.contains(req)) {
        print('  ✓ $req');
      } else {
        print('  ⚠ $req - MISSING! May cause runtime crashes');
      }
    }
    print('========================================\n');
  });
}

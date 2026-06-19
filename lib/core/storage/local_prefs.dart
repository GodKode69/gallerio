import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class LocalPrefs {
  static LocalPrefs? _instance;
  File? _file;
  Map<String, dynamic> _data = {};

  factory LocalPrefs() => _instance ??= LocalPrefs._();
  LocalPrefs._();

  Future<File> _getFile() async {
    if (_file != null) return _file!;
    final dir = await getApplicationDocumentsDirectory();
    _file = File(p.join(dir.path, 'prefs.json'));
    if (await _file!.exists()) {
      final content = await _file!.readAsString();
      _data = jsonDecode(content) as Map<String, dynamic>;
    }
    return _file!;
  }

  Future<void> _save() async {
    final file = await _getFile();
    await file.writeAsString(jsonEncode(_data));
  }

  Future<List<String>> getStringList(String key) async {
    await _getFile();
    final val = _data[key];
    if (val is List) return val.cast<String>();
    return [];
  }

  Future<void> setStringList(String key, List<String> values) async {
    await _getFile();
    _data[key] = values;
    await _save();
  }

  Future<int?> getInt(String key) async {
    await _getFile();
    final val = _data[key];
    if (val is int) return val;
    return null;
  }

  Future<void> setInt(String key, int value) async {
    await _getFile();
    _data[key] = value;
    await _save();
  }

  Future<void> remove(String key) async {
    await _getFile();
    _data.remove(key);
    await _save();
  }

  Future<bool> getBool(String key) async {
    await _getFile();
    final val = _data[key];
    if (val is bool) return val;
    return false;
  }

  Future<void> setBool(String key, bool value) async {
    await _getFile();
    _data[key] = value;
    await _save();
  }

  Future<bool> get hasCompletedOnboarding => getBool('onboarding_completed');

  Future<void> completeOnboarding() => setBool('onboarding_completed', true);

  Future<void> resetOnboarding() => setBool('onboarding_completed', false);
}

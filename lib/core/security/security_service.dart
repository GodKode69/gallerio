import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecurityService {
  static const _pinHashKey = 'gallerio_pin_hash';
  static const _pinSaltKey = 'gallerio_pin_salt';
  static const _vaultCodeHashKey = 'gallerio_vault_code_hash';
  static const _vaultCodeSaltKey = 'gallerio_vault_code_salt';
  static const _failedAttemptsKey = 'gallerio_failed_attempts';
  static const _lockoutUntilKey = 'gallerio_lockout_until';
  static const _biometricEnabledKey = 'gallerio_biometric_enabled';
  static const _vaultEnabledKey = 'gallerio_vault_enabled';
  static const _vaultCodeFailedAttemptsKey = 'gallerio_vault_code_failed_attempts';
  static const _vaultCodeLockoutUntilKey = 'gallerio_vault_code_lockout_until';

  final FlutterSecureStorage _storage;
  static const _maxFailedAttempts = 5;
  static const _shortLockout = Duration(seconds: 30);
  static const _longLockout = Duration(hours: 1);

  SecurityService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> setupPin(String pin) async {
    if (pin.length < 4 || pin.length > 6) {
      throw Exception('PIN must be 4-6 digits');
    }
    final salt = _generateSalt();
    final hash = await _hashValue(pin, salt);

    await _storage.write(key: _pinHashKey, value: hash);
    await _storage.write(
      key: _pinSaltKey,
      value: base64Encode(salt),
    );
    await _storage.write(key: _failedAttemptsKey, value: '0');
  }

  Future<bool> verifyPin(String pin) async {
    if (pin.isEmpty) return false;

    final lockoutUntil = await getLockoutUntil();
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
      return false;
    }

    final storedHash = await _storage.read(key: _pinHashKey);
    final saltBase64 = await _storage.read(key: _pinSaltKey);

    if (storedHash == null || saltBase64 == null) return false;

    final salt = base64Decode(saltBase64);
    final hash = await _hashValue(pin, salt);

    if (hash == storedHash) {
      await _storage.write(key: _failedAttemptsKey, value: '0');
      await _storage.delete(key: _lockoutUntilKey);
      return true;
    }

    await _incrementFailedAttempts();
    return false;
  }

  Future<bool> isPinSet() async {
    final hash = await _storage.read(key: _pinHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<void> changePin(String oldPin, String newPin) async {
    final verified = await verifyPin(oldPin);
    if (!verified) throw Exception('Current PIN is incorrect');
    await setupPin(newPin);
  }

  Future<void> removePin() async {
    await _storage.delete(key: _pinHashKey);
    await _storage.delete(key: _pinSaltKey);
    await _storage.delete(key: _failedAttemptsKey);
    await _storage.delete(key: _lockoutUntilKey);
  }

  Future<bool> hasVaultCode() async {
    final hash = await _storage.read(key: _vaultCodeHashKey);
    return hash != null && hash.isNotEmpty;
  }

  Future<bool> verifyVaultCode(String code) async {
    if (code.isEmpty) return false;

    final lockoutUntil = await getVaultCodeLockoutUntil();
    if (lockoutUntil != null && DateTime.now().isBefore(lockoutUntil)) {
      return false;
    }

    final storedHash = await _storage.read(key: _vaultCodeHashKey);
    final saltBase64 = await _storage.read(key: _vaultCodeSaltKey);

    if (storedHash == null || saltBase64 == null) return false;

    final salt = base64Decode(saltBase64);
    final hash = await _hashValue(code, salt);

    if (hash == storedHash) {
      await _storage.write(key: _vaultCodeFailedAttemptsKey, value: '0');
      await _storage.delete(key: _vaultCodeLockoutUntilKey);
      return true;
    }

    await _incrementVaultCodeFailedAttempts();
    return false;
  }

  Future<void> setVaultCode(String code) async {
    if (code.length < 3) {
      throw Exception('Vault code must be at least 3 characters');
    }
    final salt = _generateSalt();
    final hash = await _hashValue(code, salt);

    await _storage.write(key: _vaultCodeHashKey, value: hash);
    await _storage.write(
      key: _vaultCodeSaltKey,
      value: base64Encode(salt),
    );
  }

  Future<void> removeVaultCode() async {
    await _storage.delete(key: _vaultCodeHashKey);
    await _storage.delete(key: _vaultCodeSaltKey);
  }

  Future<int> getFailedAttempts() async {
    final val = await _storage.read(key: _failedAttemptsKey);
    return int.tryParse(val ?? '0') ?? 0;
  }

  Future<int> getRemainingAttempts() async {
    final attempts = await getFailedAttempts();
    return _maxFailedAttempts - attempts;
  }

  Future<void> _incrementFailedAttempts() async {
    final attempts = await getFailedAttempts();
    final newAttempts = attempts + 1;
    await _storage.write(
      key: _failedAttemptsKey,
      value: newAttempts.toString(),
    );

    final lockoutDuration =
        newAttempts >= _maxFailedAttempts ? _longLockout : _shortLockout;
    final lockoutUntil = DateTime.now().add(lockoutDuration);
    await _storage.write(
      key: _lockoutUntilKey,
      value: lockoutUntil.toIso8601String(),
    );
  }

  Future<DateTime?> getLockoutUntil() async {
    final val = await _storage.read(key: _lockoutUntilKey);
    if (val == null) return null;
    return DateTime.tryParse(val);
  }

  Future<int> getRemainingLockoutSeconds() async {
    final lockoutUntil = await getLockoutUntil();
    if (lockoutUntil == null) return 0;
    final remaining = lockoutUntil.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Future<bool> isBiometricEnabled() async {
    final val = await _storage.read(key: _biometricEnabledKey);
    return val == 'true';
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _storage.write(
      key: _biometricEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<bool> isVaultEnabled() async {
    final val = await _storage.read(key: _vaultEnabledKey);
    return val == 'true';
  }

  Future<void> setVaultEnabled(bool enabled) async {
    await _storage.write(
      key: _vaultEnabledKey,
      value: enabled.toString(),
    );
  }

  Future<int> getVaultCodeFailedAttempts() async {
    final val = await _storage.read(key: _vaultCodeFailedAttemptsKey);
    return int.tryParse(val ?? '0') ?? 0;
  }

  Future<int> getVaultCodeRemainingAttempts() async {
    final attempts = await getVaultCodeFailedAttempts();
    return _maxFailedAttempts - attempts;
  }

  Future<void> _incrementVaultCodeFailedAttempts() async {
    final attempts = await getVaultCodeFailedAttempts();
    final newAttempts = attempts + 1;
    await _storage.write(
      key: _vaultCodeFailedAttemptsKey,
      value: newAttempts.toString(),
    );

    final lockoutDuration =
        newAttempts >= _maxFailedAttempts ? _longLockout : _shortLockout;
    final lockoutUntil = DateTime.now().add(lockoutDuration);
    await _storage.write(
      key: _vaultCodeLockoutUntilKey,
      value: lockoutUntil.toIso8601String(),
    );
  }

  Future<DateTime?> getVaultCodeLockoutUntil() async {
    final val = await _storage.read(key: _vaultCodeLockoutUntilKey);
    if (val == null) return null;
    return DateTime.tryParse(val);
  }

  Future<int> getVaultCodeRemainingLockoutSeconds() async {
    final lockoutUntil = await getVaultCodeLockoutUntil();
    if (lockoutUntil == null) return 0;
    final remaining = lockoutUntil.difference(DateTime.now()).inSeconds;
    return remaining > 0 ? remaining : 0;
  }

  Uint8List _generateSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(16, (_) => random.nextInt(256)),
    );
  }

  Future<String> _hashValue(String value, Uint8List salt) async {
    final algorithm =
        Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 100000, bits: 256);
    final secretKey = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(value)),
      nonce: salt,
    );
    final keyData = await secretKey.extract();
    return base64Encode(keyData.bytes);
  }
}

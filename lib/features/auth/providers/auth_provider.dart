import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/security_service.dart';

class AuthState {
  final bool isPinSet;
  final bool isUnlocked;
  final bool isLoading;
  final String? error;
  final int failedAttempts;
  final int lockoutSeconds;
  final bool hasVaultCode;
  final bool isVaultEnabled;
  final bool isBiometricEnabled;

  const AuthState({
    this.isPinSet = false,
    this.isUnlocked = false,
    this.isLoading = true,
    this.error,
    this.failedAttempts = 0,
    this.lockoutSeconds = 0,
    this.hasVaultCode = false,
    this.isVaultEnabled = false,
    this.isBiometricEnabled = false,
  });

  AuthState copyWith({
    bool? isPinSet,
    bool? isUnlocked,
    bool? isLoading,
    String? error,
    int? failedAttempts,
    int? lockoutSeconds,
    bool? hasVaultCode,
    bool? isVaultEnabled,
    bool? isBiometricEnabled,
  }) {
    return AuthState(
      isPinSet: isPinSet ?? this.isPinSet,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockoutSeconds: lockoutSeconds ?? this.lockoutSeconds,
      hasVaultCode: hasVaultCode ?? this.hasVaultCode,
      isVaultEnabled: isVaultEnabled ?? this.isVaultEnabled,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final SecurityService _security;
  bool _disposed = false;

  AuthNotifier(this._security) : super(const AuthState()) {
    _init();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final isPinSet = await _security.isPinSet();
      if (_disposed) return;
      final hasVaultCode = await _security.hasVaultCode();
      if (_disposed) return;
      final isVaultEnabled = await _security.isVaultEnabled();
      if (_disposed) return;
      final isBiometricEnabled = await _security.isBiometricEnabled();
      if (_disposed) return;
      state = state.copyWith(
        isPinSet: isPinSet,
        isLoading: false,
        hasVaultCode: hasVaultCode,
        isVaultEnabled: isVaultEnabled,
        isBiometricEnabled: isBiometricEnabled,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> setupPin(String pin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _security.setupPin(pin);
      final hasVaultCode = await _security.hasVaultCode();
      state = state.copyWith(
        isPinSet: true,
        isUnlocked: true,
        isLoading: false,
        hasVaultCode: hasVaultCode,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to setup PIN',
      );
    }
  }

  Future<void> verifyPin(String pin) async {
    state = state.copyWith(error: null);
    final lockoutSeconds = await _security.getRemainingLockoutSeconds();
    if (lockoutSeconds > 0) {
      state = state.copyWith(lockoutSeconds: lockoutSeconds);
      return;
    }

    final verified = await _security.verifyPin(pin);
    if (verified) {
      state = state.copyWith(isUnlocked: true);
    } else {
      final attempts = await _security.getFailedAttempts();
      final remaining = await _security.getRemainingLockoutSeconds();
      state = state.copyWith(
        error: 'Incorrect PIN',
        failedAttempts: attempts,
        lockoutSeconds: remaining,
      );
    }
  }

  Future<void> lock() async {
    state = state.copyWith(isUnlocked: false);
  }

  Future<void> setVaultCode(String code) async {
    await _security.setVaultCode(code);
    state = state.copyWith(hasVaultCode: true);
  }

  Future<void> removeVaultCode() async {
    await _security.removeVaultCode();
    state = state.copyWith(hasVaultCode: false, isVaultEnabled: false);
  }

  Future<bool> verifyVaultCode(String code) async {
    return await _security.verifyVaultCode(code);
  }

  Future<void> setVaultEnabled(bool enabled) async {
    await _security.setVaultEnabled(enabled);
    state = state.copyWith(isVaultEnabled: enabled);
  }

  Future<bool> verifyOldPin(String pin) async {
    return await _security.verifyPin(pin);
  }

  Future<void> changePin(String oldPin, String newPin) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _security.changePin(oldPin, newPin);
      state = state.copyWith(
        isLoading: false,
        isUnlocked: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().contains('incorrect')
            ? 'Current PIN is incorrect'
            : 'Failed to change PIN',
      );
    }
  }

  Future<void> removePin() async {
    await _security.removePin();
    state = state.copyWith(
      isPinSet: false,
      isUnlocked: false,
      isVaultEnabled: false,
    );
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    await _security.setBiometricEnabled(enabled);
    state = state.copyWith(isBiometricEnabled: enabled);
  }

  void setUnlocked(bool value) {
    state = state.copyWith(isUnlocked: value);
  }
}

final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

final authStateProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final security = ref.watch(securityServiceProvider);
  return AuthNotifier(security);
});

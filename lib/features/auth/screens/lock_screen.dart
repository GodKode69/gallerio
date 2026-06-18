import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import '../../../app/router.dart';
import '../providers/auth_provider.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen>
    with SingleTickerProviderStateMixin {
  final _pinController = TextEditingController();
  final _localAuth = LocalAuthentication();
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  Timer? _lockoutTimer;
  int _remainingSeconds = 0;
  int _remainingAttempts = 5;
  bool _canUseBiometric = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 20).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );
    _initLockout();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initBiometric();
    });
  }

  @override
  void dispose() {
    _pinController.dispose();
    _shakeController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLockout() async {
    try {
      final security = ref.read(securityServiceProvider);
      final remaining = await security.getRemainingLockoutSeconds();
      _remainingAttempts = await security.getRemainingAttempts();
      if (remaining > 0 && mounted) {
        _startLockoutTimer(remaining);
      }
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _initBiometric() async {
    try {
      final security = ref.read(securityServiceProvider);
      final biometricEnabled = await security.isBiometricEnabled();
      if (!biometricEnabled || !mounted) {
        if (mounted) setState(() => _canUseBiometric = false);
        return;
      }

      final canAuth = await _localAuth.canCheckBiometrics;
      if (!canAuth || !mounted) {
        if (mounted) setState(() => _canUseBiometric = false);
        return;
      }

      if (mounted) setState(() => _canUseBiometric = true);

      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access Gallerio',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
        ),
      );

      if (authenticated && mounted) {
        ref.read(authStateProvider.notifier).setUnlocked(true);
        AppNavigator.goToGallery(context);
      }
    } catch (e) {
      if (mounted) setState(() => _canUseBiometric = false);
    }
  }

  void _onDigitPressed(String digit) {
    if (_remainingSeconds > 0) return;
    if (_pinController.text.length < 6) {
      HapticFeedback.lightImpact();
      _pinController.text += digit;
      setState(() {});
      if (_pinController.text.length == 6) {
        _verifyPin();
      }
    }
  }

  void _onBackspace() {
    if (_pinController.text.isNotEmpty) {
      HapticFeedback.lightImpact();
      _pinController.text = _pinController.text
          .substring(0, _pinController.text.length - 1);
      setState(() {});
    }
  }

  void _onSubmit() {
    if (_pinController.text.length < 4 || _remainingSeconds > 0) return;
    _verifyPin();
  }

  Future<void> _verifyPin() async {
    if (!mounted) return;

    final pin = _pinController.text;
    final notifier = ref.read(authStateProvider.notifier);
    final security = ref.read(securityServiceProvider);

    await notifier.verifyPin(pin);

    if (!mounted) return;

    final state = ref.read(authStateProvider);
    if (state.isUnlocked) {
      _lockoutTimer?.cancel();
      AppNavigator.goToGallery(context);
    } else if (state.error != null) {
      _shakeController.forward(from: 0);
      _pinController.clear();

      _remainingAttempts = await security.getRemainingAttempts();
      final lockoutSecs = await security.getRemainingLockoutSeconds();

      if (!mounted) return;
      setState(() {});

      if (lockoutSecs > 0) {
        _startLockoutTimer(lockoutSecs);
      }
    }
  }

  void _startLockoutTimer(int seconds) {
    _lockoutTimer?.cancel();
    _remainingSeconds = seconds;
    setState(() {});

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _remainingSeconds--;
      });
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _remainingSeconds = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final locked = _remainingSeconds > 0;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 80),
            const Icon(
              Icons.lock_outline,
              size: 56,
              color: Colors.white70,
            ),
            const SizedBox(height: 20),
            const Text(
              'Enter PIN',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (locked)
              Text(
                'Locked for ${_remainingSeconds}s',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                ),
              )
            else if (authState.error != null)
              Text(
                '${authState.error!}. $_remainingAttempts attempts remaining.',
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              )
            else
              Text(
                'Tap digits to enter your PIN',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            const SizedBox(height: 40),
            AnimatedBuilder(
              animation: _shakeAnimation,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(_shakeAnimation.value, 0),
                  child: child,
                );
              },
              child: _buildPinDots(),
            ),
            const Spacer(),
            _buildKeypad(),
            const SizedBox(height: 20),
            if (_canUseBiometric)
              TextButton(
                onPressed: locked ? null : _initBiometric,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fingerprint,
                        size: 20,
                        color: locked
                            ? Colors.white24
                            : Colors.white70),
                    const SizedBox(width: 6),
                    Text(
                      'Use biometric',
                      style: TextStyle(
                        color: locked ? Colors.white24 : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPinDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final filled = index < _pinController.text.length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled
                ? Theme.of(context).colorScheme.primary
                : Colors.white.withValues(alpha: 0.15),
          ),
        );
      }),
    );
  }

  Widget _buildKeypad() {
    final locked = _remainingSeconds > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          for (var row in [
            ['1', '2', '3'],
            ['4', '5', '6'],
            ['7', '8', '9'],
            ['', '0', '⌫'],
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: row.map((digit) {
                  if (digit.isEmpty) {
                    return _buildSubmitButton(locked);
                  }
                  if (digit == '⌫') {
                    return _buildKey(digit,
                        onTap: _onBackspace, isIcon: true, locked: locked);
                  }
                  return _buildKey(digit,
                      onTap: () => _onDigitPressed(digit), locked: locked);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton(bool locked) {
    final canSubmit =
        _pinController.text.length >= 4 && !locked;
    return GestureDetector(
      onTap: canSubmit ? _onSubmit : null,
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: canSubmit
              ? Theme.of(context).colorScheme.primary
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.check,
          color: canSubmit
              ? Colors.white
              : Colors.white.withValues(alpha: 0.15),
          size: 24,
        ),
      ),
    );
  }

  Widget _buildKey(
    String digit, {
    required VoidCallback onTap,
    bool isIcon = false,
    bool locked = false,
  }) {
    return GestureDetector(
      onTap: locked ? null : onTap,
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: locked ? 0.03 : 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: isIcon
            ? Icon(
                Icons.backspace_outlined,
                color: Colors.white70.withValues(alpha: locked ? 0.3 : 1),
                size: 22,
              )
            : Text(
                digit,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color:
                      Colors.white.withValues(alpha: locked ? 0.3 : 1),
                ),
              ),
      ),
    );
  }
}

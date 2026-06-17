import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  final bool changeMode;
  const PinSetupScreen({super.key, this.changeMode = false});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  int _step = 0;
  String _firstPin = '';
  String _oldPin = '';
  String? _error;

  bool get _isChangeMode => widget.changeMode;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_currentController.text.length < 6) {
      _currentController.text += digit;
    }
    setState(() {});
  }

  void _onBackspace() {
    if (_currentController.text.isNotEmpty) {
      _currentController.text = _currentController.text
          .substring(0, _currentController.text.length - 1);
    }
    setState(() {});
  }

  TextEditingController get _currentController {
    if (_isChangeMode && _step == 0) return _pinController;
    if (_step == (_isChangeMode ? 1 : 0)) return _pinController;
    return _confirmController;
  }

  int get _currentLength => _currentController.text.length;

  String get _title {
    if (_isChangeMode) {
      switch (_step) {
        case 0:
          return 'Enter old PIN';
        case 1:
          return 'Create new PIN';
        case 2:
          return 'Confirm new PIN';
      }
    }
    return _step == 0 ? 'Create a PIN' : 'Confirm your PIN';
  }

  String get _subtitle {
    if (_isChangeMode) {
      switch (_step) {
        case 0:
          return 'Verify your current PIN';
        case 1:
          return 'Use 4-6 digits for your new PIN';
        case 2:
          return 'Re-enter your new PIN to confirm';
      }
    }
    return _step == 0
        ? 'Use 4-6 digits to secure your vault'
        : 'Re-enter your PIN to confirm';
  }

  String get _buttonLabel {
    if (_isChangeMode) {
      switch (_step) {
        case 0:
          return 'Verify';
        case 1:
          return 'Next';
        case 2:
          return 'Change PIN';
      }
    }
    return _step == 0 ? 'Next' : 'Confirm';
  }

  Future<void> _onNext() async {
    final authNotifier = ref.read(authStateProvider.notifier);

    if (_isChangeMode && _step == 0) {
      final verified = await authNotifier.verifyOldPin(_pinController.text);
      if (!mounted) return;
      if (!verified) {
        setState(() => _error = 'Incorrect current PIN');
        _pinController.clear();
        return;
      }
      _oldPin = _pinController.text;
      _pinController.clear();
      setState(() {
        _step = 1;
        _error = null;
      });
    } else if (!_isChangeMode && _step == 0) {
      _firstPin = _pinController.text;
      _confirmController.clear();
      setState(() => _step = 1);
    } else {
      final isNewPinStep = _isChangeMode && _step == 1;
      if (isNewPinStep) {
        _firstPin = _pinController.text;
        _pinController.clear();
        setState(() => _step = 2);
        return;
      }

      if (_confirmController.text == _firstPin && _confirmController.text.length >= 4) {
        if (_isChangeMode) {
          await authNotifier.changePin(_oldPin, _confirmController.text);
          _firstPin = '';
          _oldPin = '';
          if (mounted) context.pop();
        } else {
          await authNotifier.setupPin(_confirmController.text);
          _firstPin = '';
          if (mounted) {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/gallery');
            }
          }
        }
      } else {
        setState(() => _error = 'PINs do not match');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (next.isUnlocked && next.isPinSet && !_isChangeMode) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/gallery');
        }
      }
    });

    final displayError = _error ?? authState.error;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(
              Icons.lock_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              _title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 40),
            _buildPinDots(),
            if (displayError != null) ...[
              const SizedBox(height: 16),
              Text(
                displayError,
                style: const TextStyle(
                    color: Colors.redAccent, fontSize: 14),
              ),
            ],
            if (_step >= 1 &&
                _currentController.text.isNotEmpty &&
                _currentLength >= 4 &&
                _error == null)
              const SizedBox(height: 16),
            const Spacer(),
            _buildKeypad(),
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
        final filled = index < _currentLength;
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
    final authState = ref.read(authStateProvider);
    final canProceed = _currentLength >= 4 && !authState.isLoading;
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
                  if (digit.isEmpty) return const SizedBox(width: 72);
                  if (digit == '⌫') {
                    return _buildKey(
                      digit,
                      onTap: _onBackspace,
                      isIcon: true,
                    );
                  }
                  return _buildKey(
                    digit,
                    onTap: () => _onDigitPressed(digit),
                  );
                }).toList(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: SizedBox(
              width: 200,
              height: 52,
              child: FilledButton(
                onPressed: canProceed ? _onNext : null,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  disabledBackgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  authState.isLoading ? 'Please wait...' : _buttonLabel,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKey(
    String digit, {
    required VoidCallback onTap,
    bool isIcon = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: isIcon
            ? const Icon(Icons.backspace_outlined,
                color: Colors.white70, size: 22)
            : Text(
                digit,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }
}

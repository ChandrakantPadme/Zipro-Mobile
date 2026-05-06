import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_providers.dart';
import 'login_flow_models.dart';
import 'login_theme.dart';

const _kVerifyOtpHero = 'assets/images/login3.png';

class VerifyOtpScreen extends ConsumerStatefulWidget {
  const VerifyOtpScreen({
    super.key,
    required this.extra,
  });

  final VerifyOtpExtra extra;

  @override
  ConsumerState<VerifyOtpScreen> createState() => _VerifyOtpScreenState();
}

class _VerifyOtpScreenState extends ConsumerState<VerifyOtpScreen> {
  final _hiddenCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _loading = false;
  String? _error;
  static const _otpLength = 6;
  static const _resendSeconds = 45;
  int _resendRemaining = _resendSeconds;
  Timer? _timer;
  String? _lastAutoVerifyAttempt;

  @override
  void initState() {
    super.initState();
    _hiddenCtrl.addListener(() {
      final t = _hiddenCtrl.text;
      if (t.length > _otpLength) {
        _hiddenCtrl.text = t.substring(0, _otpLength);
        _hiddenCtrl.selection =
            const TextSelection.collapsed(offset: _otpLength);
      }
      if (t.length < _otpLength) {
        _lastAutoVerifyAttempt = null;
      }
      setState(() {});
      if (t.length == _otpLength && !_loading && t != _lastAutoVerifyAttempt) {
        _lastAutoVerifyAttempt = t;
        _verify();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _startResendTimer();
    });
  }

  void _startResendTimer() {
    _timer?.cancel();
    setState(() => _resendRemaining = _resendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendRemaining <= 1) {
        timer.cancel();
        setState(() => _resendRemaining = 0);
      } else {
        setState(() => _resendRemaining -= 1);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _hiddenCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final otp = _hiddenCtrl.text.trim();
    if (otp.length != _otpLength) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    final err = await ref.read(authNotifierProvider).verifyLoginOtp(
          channel: widget.extra.channel,
          identifier: widget.extra.identifier,
          otp: otp,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() {
        _error = err;
        _lastAutoVerifyAttempt = null;
      });
    }
  }

  Future<void> _resend() async {
    if (_resendRemaining > 0) return;
    setState(() => _error = null);
    final err = await ref.read(authNotifierProvider).requestLoginOtp(
          channel: widget.extra.channel,
          identifier: widget.extra.identifier,
        );
    if (!mounted) return;
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    _hiddenCtrl.clear();
    _startResendTimer();
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final code = _hiddenCtrl.text;

    return Scaffold(
      backgroundColor: LoginTheme.navyDeep,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            _kVerifyOtpHero,
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.18),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.42),
                ],
                stops: const [0.0, 0.42, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + bottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Verify your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 15,
                        height: 1.35,
                      ),
                      children: [
                        const TextSpan(text: "We've sent a 6-digit code to "),
                        TextSpan(
                          text: widget.extra.displayContact,
                          style: const TextStyle(
                            color: LoginTheme.orange,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  Stack(
                    children: [
                      Opacity(
                        opacity: 0,
                        child: TextField(
                          controller: _hiddenCtrl,
                          focusNode: _focusNode,
                          keyboardType: TextInputType.number,
                          maxLength: _otpLength,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly
                          ],
                          decoration: const InputDecoration(counterText: ''),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _focusNode.requestFocus(),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(_otpLength, (i) {
                            final hasDigit = i < code.length;
                            final char = hasDigit ? code[i] : '';
                            final activeIndex = code.length >= _otpLength
                                ? _otpLength - 1
                                : code.length;
                            final active = i == activeIndex;
                            return Padding(
                              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 160),
                                width: 48,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: LoginTheme.otpBoxFill,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: active
                                        ? LoginTheme.orange
                                        : LoginTheme.otpBorder,
                                    width: active ? 2 : 1,
                                  ),
                                ),
                                child: Text(
                                  char,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 18,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                      const SizedBox(width: 6),
                      if (_resendRemaining > 0)
                        Text.rich(
                          TextSpan(
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.55),
                              fontSize: 14,
                            ),
                            children: [
                              const TextSpan(text: 'Resend code in '),
                              TextSpan(
                                text:
                                    '00:${_resendRemaining.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  color: LoginTheme.orange,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        TextButton(
                          onPressed: _loading ? null : _resend,
                          child: const Text(
                            'Resend code',
                            style: TextStyle(
                              color: LoginTheme.orange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Color(0xFFFCA5A5), fontSize: 14),
                    ),
                  ],
                  const Spacer(),
                  OutlinedButton.icon(
                    onPressed: _loading
                        ? null
                        : () {
                            context.pop();
                          },
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    label: Text(
                      widget.extra.channel == 'EMAIL'
                          ? 'Change email'
                          : 'Change phone',
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loading ? null : () => context.go('/login'),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    label: const Text('Use another method'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                          color: Colors.white.withValues(alpha: 0.3)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed:
                        _loading || code.length != _otpLength ? null : _verify,
                    style: FilledButton.styleFrom(
                      backgroundColor: LoginTheme.orange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          LoginTheme.orange.withValues(alpha: 0.4),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Verify',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 16,
                        color: Colors.white.withValues(alpha: 0.35),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Your data is safe with us',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

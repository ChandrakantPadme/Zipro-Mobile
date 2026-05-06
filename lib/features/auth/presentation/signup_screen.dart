import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_providers.dart';
import 'login_theme.dart';
import 'widgets/auth_method_toggle.dart';
import 'widgets/zipro_logo_png.dart';

class _CountryOption {
  const _CountryOption({required this.code, required this.name, required this.phone});
  final String code;
  final String name;
  final String phone;
}

const _countries = <_CountryOption>[
  _CountryOption(code: 'US', name: 'United States', phone: '+1'),
  _CountryOption(code: 'IN', name: 'India', phone: '+91'),
  _CountryOption(code: 'GB', name: 'United Kingdom', phone: '+44'),
  _CountryOption(code: 'AE', name: 'United Arab Emirates', phone: '+971'),
  _CountryOption(code: 'SG', name: 'Singapore', phone: '+65'),
  _CountryOption(code: 'AU', name: 'Australia', phone: '+61'),
  _CountryOption(code: 'DE', name: 'Germany', phone: '+49'),
  _CountryOption(code: 'FR', name: 'France', phone: '+33'),
];

enum _SignupStep { info, contact, otp }

/// Login-aligned field decoration (matches [LoginDetailsScreen] inputs).
InputDecoration _signupFieldDecoration({
  required String label,
  String? hint,
  Widget? prefixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    labelStyle: const TextStyle(color: LoginTheme.textMuted, fontSize: 14),
    hintStyle: TextStyle(color: LoginTheme.textMuted.withValues(alpha: 0.65)),
    prefixIcon: prefixIcon,
    floatingLabelBehavior: FloatingLabelBehavior.auto,
    filled: true,
    fillColor: LoginTheme.sheetWhite,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: LoginTheme.borderSubtle),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: LoginTheme.borderSubtle),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: LoginTheme.orange, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.destructive),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: AppColors.destructive, width: 1.5),
    ),
  );
}

ButtonStyle _signupPrimaryButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: LoginTheme.orange,
    foregroundColor: Colors.white,
    disabledBackgroundColor: LoginTheme.orange.withValues(alpha: 0.45),
    padding: const EdgeInsets.symmetric(vertical: 16),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _countryCode = '+91';
  String _countryIso = 'IN';
  _SignupStep _step = _SignupStep.info;
  bool _contactIsEmail = true;
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  bool _validateInfo() {
    if (_firstNameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please fill in your name');
      return false;
    }
    if (_emailCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your email');
      return false;
    }
    final emailRe = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRe.hasMatch(_emailCtrl.text.trim())) {
      setState(() => _error = 'Please enter a valid email');
      return false;
    }
    if (_phoneCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Please enter your phone number');
      return false;
    }
    if (_countryIso.isEmpty) {
      setState(() => _error = 'Please select your country');
      return false;
    }
    return true;
  }

  Future<void> _submitContact() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final auth = ref.read(authNotifierProvider);
    final err = await auth.signupRequest(
      firstName: _firstNameCtrl.text,
      lastName: _lastNameCtrl.text,
      email: _emailCtrl.text,
      phone: _phoneCtrl.text,
      countryCode: _countryCode,
      verifyChannel: _contactIsEmail ? 'EMAIL' : 'PHONE',
    );
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (err != null) {
        _error = err;
      } else {
        _step = _SignupStep.otp;
      }
    });
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    final channel = _contactIsEmail ? 'EMAIL' : 'PHONE';
    final identifier = _contactIsEmail
        ? _emailCtrl.text.trim()
        : '$_countryCode${_phoneCtrl.text.trim()}';
    final err = await ref.read(authNotifierProvider).verifySignupOtp(
          channel: channel,
          identifier: identifier,
          otp: otp,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) setState(() => _error = err);
  }

  String _stepTitle() {
    return switch (_step) {
      _SignupStep.info => 'Personal info',
      _SignupStep.contact => 'Verification method',
      _SignupStep.otp => 'Verify OTP',
    };
  }

  String? _stepSubtitle() {
    return switch (_step) {
      _SignupStep.info => 'Tell us a bit about you to create your account.',
      _SignupStep.contact => 'Choose where we should send your one-time code.',
      _SignupStep.otp => 'Enter the 6-digit code we sent you.',
    };
  }

  void _onBack() {
    if (_step == _SignupStep.info) {
      context.go('/login');
      return;
    }
    if (_step == _SignupStep.otp) {
      setState(() {
        _step = _SignupStep.contact;
        _otpCtrl.clear();
        _error = null;
      });
      return;
    }
    setState(() {
      _step = _SignupStep.info;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: LoginTheme.sheetWhite,
      appBar: AppBar(
        backgroundColor: LoginTheme.sheetWhite,
        foregroundColor: LoginTheme.textNavy,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _onBack,
        ),
        title: Text(
          'Create account',
          style: TextStyle(
            color: LoginTheme.textNavy,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Center(child: ZiproLogoPng(height: 44)),
              const SizedBox(height: 24),
              Text(
                _stepTitle(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: LoginTheme.textNavy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _stepSubtitle()!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.35,
                  color: LoginTheme.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: TextStyle(
                        fontSize: 14,
                        color: LoginTheme.textMuted,
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        foregroundColor: LoginTheme.orange,
                      ),
                      child: const Text(
                        'Sign in',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (_step == _SignupStep.info) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _firstNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _signupFieldDecoration(label: 'First name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _lastNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _signupFieldDecoration(label: 'Last name'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  decoration: _signupFieldDecoration(
                    label: 'Email',
                    hint: 'you@example.com',
                    prefixIcon: Icon(
                      Icons.mail_outline_rounded,
                      color: LoginTheme.orange.withValues(alpha: 0.9),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 112,
                      child: DropdownButtonFormField<String>(
                        value: _countries.any((c) => c.phone == _countryCode)
                            ? _countryCode
                            : _countries.first.phone,
                        isExpanded: true,
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: LoginTheme.textMuted,
                        ),
                        decoration: _signupFieldDecoration(label: 'Code'),
                        items: [
                          for (final c in _countries)
                            DropdownMenuItem(value: c.phone, child: Text(c.phone)),
                        ],
                        onChanged: (v) {
                          if (v == null) return;
                          final c = _countries.firstWhere((x) => x.phone == v);
                          setState(() {
                            _countryCode = v;
                            _countryIso = c.code;
                            if (_countryIso != 'IN') _contactIsEmail = true;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        textInputAction: TextInputAction.next,
                        decoration: _signupFieldDecoration(
                          label: 'Phone number',
                          prefixIcon: Icon(
                            Icons.phone_iphone_rounded,
                            color: LoginTheme.navy.withValues(alpha: 0.75),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _countryIso.isEmpty ? null : _countryIso,
                  isExpanded: true,
                  icon: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: LoginTheme.textMuted,
                  ),
                  decoration: _signupFieldDecoration(label: 'Country'),
                  hint: Text(
                    'Select country',
                    style: TextStyle(color: LoginTheme.textMuted.withValues(alpha: 0.7)),
                  ),
                  items: [
                    for (final c in _countries)
                      DropdownMenuItem(value: c.code, child: Text(c.name)),
                  ],
                  onChanged: (v) {
                    if (v == null) return;
                    final c = _countries.firstWhere((x) => x.code == v);
                    setState(() {
                      _countryIso = v;
                      _countryCode = c.phone;
                      if (_countryIso != 'IN') _contactIsEmail = true;
                    });
                  },
                ),
                const SizedBox(height: 28),
                FilledButton(
                  style: _signupPrimaryButtonStyle(),
                  onPressed: _loading
                      ? null
                      : () {
                          setState(() => _error = null);
                          if (!_validateInfo()) return;
                          setState(() => _step = _SignupStep.contact);
                        },
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              if (_step == _SignupStep.contact) ...[
                if (_countryIso == 'IN') ...[
                  AuthMethodToggle(
                    useEmail: _contactIsEmail,
                    onChanged: (v) => setState(() => _contactIsEmail = v),
                  ),
                  const SizedBox(height: 20),
                ] else ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: LoginTheme.borderSubtle.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'We will send the code to ${_emailCtrl.text.trim()}.',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: LoginTheme.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                FilledButton(
                  style: _signupPrimaryButtonStyle(),
                  onPressed: _loading ? null : _submitContact,
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
                          'Send code',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
              if (_step == _SignupStep.otp) ...[
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: _signupFieldDecoration(
                    label: '6-digit code',
                  ).copyWith(counterText: ''),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  style: _signupPrimaryButtonStyle(),
                  onPressed: _loading ? null : _verifyOtp,
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
                          'Create account',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 20),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.destructive,
                    fontSize: 14,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

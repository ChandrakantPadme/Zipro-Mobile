import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_providers.dart';
import 'login_flow_models.dart';
import 'login_theme.dart';
import 'widgets/auth_method_toggle.dart';
import 'widgets/zipro_logo_png.dart';

const _kLoginDetailsHero = 'assets/images/login2.png';

class LoginDetailsScreen extends ConsumerStatefulWidget {
  const LoginDetailsScreen({
    super.key,
    required this.initialEmail,
  });

  final bool initialEmail;

  @override
  ConsumerState<LoginDetailsScreen> createState() => _LoginDetailsScreenState();
}

class _LoginDetailsScreenState extends ConsumerState<LoginDetailsScreen> {
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _countryCodeCtrl = TextEditingController(text: '+91');
  late bool _useEmail;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _useEmail = widget.initialEmail;
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _countryCodeCtrl.dispose();
    super.dispose();
  }

  String _identifier() {
    if (_useEmail) return _emailCtrl.text.trim();
    final digits = _phoneCtrl.text.trim();
    final cc = _countryCodeCtrl.text.trim();
    return '$cc$digits';
  }

  String _displayContact() {
    if (_useEmail) return _emailCtrl.text.trim();
    final digits = _phoneCtrl.text.trim();
    final cc = _countryCodeCtrl.text.trim();
    return '$cc $digits'.trim();
  }

  Future<void> _continue() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    final id = _identifier();
    if (id.isEmpty || (_useEmail == false && _phoneCtrl.text.trim().isEmpty)) {
      setState(() {
        _error = _useEmail ? 'Please enter your email' : 'Please enter your phone number';
        _loading = false;
      });
      return;
    }
    final channel = _useEmail ? 'EMAIL' : 'PHONE';
    final err = await ref.read(authNotifierProvider).requestLoginOtp(
          channel: channel,
          identifier: id,
        );
    if (!mounted) return;
    setState(() => _loading = false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    if (!mounted) return;
    context.push(
      '/login/verify',
      extra: VerifyOtpExtra(
        channel: channel,
        identifier: id,
        displayContact: _displayContact(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: LoginTheme.navyDeep,
      body: Column(
        children: [
          Expanded(
            flex: 12,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _kLoginDetailsHero,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.22),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.55],
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 4),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: const CircleBorder(),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => context.pop(),
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 12,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: LoginTheme.sheetWhite,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(LoginTheme.sheetTopRadius),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ZiproLogoPng(height: 44),
                    const SizedBox(height: 16),
                    const Text(
                      "Let's get you in",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: LoginTheme.textNavy,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Choose a method and enter your details',
                      style: TextStyle(
                        fontSize: 15,
                        color: LoginTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 20),
                    AuthMethodToggle(
                      useEmail: _useEmail,
                      onChanged: (v) {
                        setState(() {
                          _useEmail = v;
                          _error = null;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    if (_useEmail)
                      TextField(
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        style: const TextStyle(
                          fontSize: 16,
                          color: LoginTheme.textNavy,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          labelText: 'Email address',
                          labelStyle: const TextStyle(color: LoginTheme.textMuted),
                          hintText: 'you@example.com',
                          hintStyle: TextStyle(
                            color: LoginTheme.textMuted.withValues(alpha: 0.65),
                          ),
                          prefixIcon: Icon(
                            Icons.mail_outline_rounded,
                            color: LoginTheme.orange.withValues(alpha: 0.9),
                          ),
                          filled: true,
                          fillColor: LoginTheme.sheetWhite,
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
                        ),
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 92,
                            child: TextField(
                              controller: _countryCodeCtrl,
                              keyboardType: TextInputType.phone,
                              style: const TextStyle(
                                fontSize: 16,
                                color: LoginTheme.textNavy,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Code',
                                labelStyle: const TextStyle(color: LoginTheme.textMuted),
                                filled: true,
                                fillColor: LoginTheme.sheetWhite,
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
                                  borderSide:
                                      const BorderSide(color: LoginTheme.orange, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              style: const TextStyle(
                                fontSize: 16,
                                color: LoginTheme.textNavy,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                labelText: 'Phone number',
                                labelStyle: const TextStyle(color: LoginTheme.textMuted),
                                prefixIcon: Icon(
                                  Icons.phone_iphone_rounded,
                                  color: LoginTheme.navy.withValues(alpha: 0.75),
                                ),
                                filled: true,
                                fillColor: LoginTheme.sheetWhite,
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
                                  borderSide:
                                      const BorderSide(color: LoginTheme.orange, width: 1.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontSize: 14,
                        ),
                      ),
                    ],
                    const Spacer(),
                    FilledButton(
                      onPressed: _loading ? null : _continue,
                      style: FilledButton.styleFrom(
                        backgroundColor: LoginTheme.orange,
                        foregroundColor: Colors.white,
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
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Continue',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 20),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        alignment: WrapAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(
                              fontSize: 14,
                              color: LoginTheme.textMuted,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.push('/signup'),
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              foregroundColor: LoginTheme.orange,
                            ),
                            child: const Text(
                              'Sign up',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

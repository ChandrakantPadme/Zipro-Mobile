import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'login_theme.dart';
import 'widgets/zipro_logo_png.dart';

/// Landing step: photo hero + bottom sign-in sheet with logo on card.
class WelcomeLoginScreen extends StatelessWidget {
  const WelcomeLoginScreen({super.key});

  static const _heroAsset = 'assets/images/mobilebk.png';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: LoginTheme.navyDeep,
      body: Column(
        children: [
          Expanded(
            flex: 13,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  _heroAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.28),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.5),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.04),
                        Colors.transparent,
                        Colors.white.withValues(alpha: 0.03),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 11,
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: LoginTheme.sheetWhite,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(LoginTheme.sheetTopRadius),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 20 + bottomInset),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const ZiproLogoPng(height: 44),
                    const SizedBox(height: 16),
                    const Text(
                      'Log in to your account',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: LoginTheme.textNavy,
                      ),
                    ),
                    // const SizedBox(height: 6),
                    // const Text(
                    //   'Sign in to continue',
                    //   style: TextStyle(
                    //     fontSize: 15,
                    //     color: LoginTheme.textMuted,
                    //   ),
                    // ),
                    const SizedBox(height: 24),
                    _AuthMethodTile(
                      icon: Icons.mail_outline_rounded,
                      iconColor: LoginTheme.orange,
                      label: 'Continue with Email',
                      onTap: () => context.push('/login/details', extra: true),
                    ),
                    const SizedBox(height: 14),
                    _AuthMethodTile(
                      icon: Icons.phone_iphone_rounded,
                      iconColor: LoginTheme.navy,
                      label: 'Continue with Phone',
                      onTap: () => context.push('/login/details', extra: false),
                    ),
                    const Spacer(),
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

class _AuthMethodTile extends StatelessWidget {
  const _AuthMethodTile({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: LoginTheme.sheetWhite,
      borderRadius: BorderRadius.circular(LoginTheme.controlRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LoginTheme.controlRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LoginTheme.controlRadius),
            border: Border.all(color: LoginTheme.borderSubtle, width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: iconColor, size: 24),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: LoginTheme.textNavy,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: LoginTheme.textMuted.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../login_theme.dart';

/// Email / phone pills matching login details screen.
class AuthMethodToggle extends StatelessWidget {
  const AuthMethodToggle({
    super.key,
    required this.useEmail,
    required this.onChanged,
  });

  final bool useEmail;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MethodChip(
            selected: useEmail,
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            onTap: () => onChanged(true),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MethodChip(
            selected: !useEmail,
            icon: Icons.phone_iphone_rounded,
            label: 'Phone',
            onTap: () => onChanged(false),
          ),
        ),
      ],
    );
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? LoginTheme.orange : LoginTheme.borderSubtle;
    final iconColor = selected ? LoginTheme.orange : LoginTheme.textMuted;
    final textColor = selected ? LoginTheme.textNavy : LoginTheme.textMuted;

    return Material(
      color: LoginTheme.sheetWhite,
      borderRadius: BorderRadius.circular(LoginTheme.controlRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LoginTheme.controlRadius),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(LoginTheme.controlRadius),
            border: Border.all(color: borderColor, width: selected ? 2 : 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 22, color: iconColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

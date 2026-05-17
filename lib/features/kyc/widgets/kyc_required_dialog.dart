import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';

/// Mirrors [zipro_website_new/contexts/KycRequiredDialogContext.tsx].
///
/// Shows a "Complete your KYC first" dialog with an action-specific message
/// (e.g. "to accept an order request"). Navigates to `/kyc` when the user
/// taps "Go to KYC".
class KycRequiredDialog extends StatelessWidget {
  const KycRequiredDialog({super.key, this.actionLabel});

  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final desc = actionLabel != null && actionLabel!.isNotEmpty
        ? 'Please complete your KYC first to $actionLabel.'
        : 'Please complete your KYC first to continue this action.';
    return AlertDialog(
      title: const Text('Complete your KYC first'),
      content: Text(
        desc,
        style: TextStyle(color: AppColors.mutedForeground, fontSize: 14),
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(true);
            context.push('/kyc');
          },
          child: const Text('Go to KYC'),
        ),
      ],
    );
  }
}

/// Convenience helper to surface the KYC dialog from any caller.
Future<void> showKycRequiredDialog(
  BuildContext context, {
  String? actionLabel,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (_) => KycRequiredDialog(actionLabel: actionLabel),
  );
}

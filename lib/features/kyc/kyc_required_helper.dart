import 'package:flutter/material.dart';

import '../../core/network/dio_error_mapper.dart';
import 'widgets/kyc_required_dialog.dart';

/// Wraps [action] and intercepts `KYC_REQUIRED` API errors with a dialog.
/// Other errors are forwarded to [onError] for the caller to handle (e.g.
/// show a SnackBar). Mirrors the `isKycRequiredError` interception used in
/// web hooks (`useAcceptMatch`, `useCreateShipment`, etc.).
Future<T?> runWithKycGuard<T>(
  BuildContext context, {
  required Future<T> Function() action,
  required String actionLabel,
  void Function(Object error)? onError,
}) async {
  try {
    return await action();
  } catch (e) {
    if (isKycRequiredError(e)) {
      if (context.mounted) {
        await showKycRequiredDialog(context, actionLabel: actionLabel);
      }
      return null;
    }
    if (onError != null) {
      onError(e);
    }
    return null;
  }
}

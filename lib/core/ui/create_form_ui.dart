import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shared layout and decoration for [SendOrShopScreen] and [TravelEarnScreen].
abstract final class CreateFormUi {
  CreateFormUi._();

  static const double fieldGap = 18;
  static const double sectionGap = 36;
  static const double wideBreakpoint = 560;
  static const EdgeInsets scrollPadding = EdgeInsets.fromLTRB(20, 12, 20, 32);

  /// Matches [buildAppTheme] inputs — filled surface + rounded outline so floating
  /// labels do not visually slice through the border.
  static OutlineInputBorder outlineBorder({Color? borderColor}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: borderColor ?? AppColors.border),
    );
  }

  static InputDecoration inputDecoration({
    required String label,
    String? hint,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      alignLabelWithHint: alignLabelWithHint,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      filled: true,
      fillColor: Colors.white,
      isDense: false,
      contentPadding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      border: outlineBorder(),
      enabledBorder: outlineBorder(),
      focusedBorder: outlineBorder(
        borderColor: AppColors.primary.withValues(alpha: 0.65),
      ),
      errorBorder: outlineBorder(borderColor: AppColors.destructive),
      focusedErrorBorder: outlineBorder(borderColor: AppColors.destructive),
    );
  }

  /// URL rows in product-link lists (hint only, no label).
  static InputDecoration linkInputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint ?? 'https://example.com/product/1',
      filled: true,
      fillColor: Colors.white,
      isDense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: outlineBorder(),
      enabledBorder: outlineBorder(),
      focusedBorder: outlineBorder(
        borderColor: AppColors.primary.withValues(alpha: 0.65),
      ),
    );
  }

  static Widget sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.foreground,
            ),
      ),
    );
  }

  static Widget heroHeader({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
          ),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: 28,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.35,
                  color: AppColors.mutedForeground,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Side-by-side on wide screens; stacked with [fieldGap] on narrow.
  static Widget pairRow({
    required bool wide,
    required Widget first,
    required Widget second,
  }) {
    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: fieldGap),
          Expanded(child: second),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        first,
        const SizedBox(height: fieldGap),
        second,
      ],
    );
  }
}

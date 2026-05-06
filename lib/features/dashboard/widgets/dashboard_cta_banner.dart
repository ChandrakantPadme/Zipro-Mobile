import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class DashboardCtaBanner extends StatelessWidget {
  const DashboardCtaBanner({
    super.key,
    required this.backgroundColor,
    required this.arrowColor,
    required this.icon,
    required this.decorationIcon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final Color backgroundColor;
  final Color arrowColor;
  final IconData icon;
  final IconData decorationIcon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textOnBanner = _contrastOn(backgroundColor);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                Positioned(
                  right: -8,
                  bottom: -12,
                  child: Icon(
                    decorationIcon,
                    size: 96,
                    color: textOnBanner.withValues(alpha: 0.12),
                  ),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: textOnBanner.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(icon, size: 24, color: textOnBanner),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.2,
                                color: textOnBanner,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.35,
                                color: textOnBanner.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: arrowColor == backgroundColor
                            ? textOnBanner
                            : arrowColor,
                        size: 26,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Picks white or dark text for readability on [bg].
  static Color _contrastOn(Color bg) {
    final luminance = bg.computeLuminance();
    return luminance > 0.55 ? AppColors.foreground : Colors.white;
  }
}

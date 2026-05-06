import 'package:flutter/material.dart';

/// Full wordmark from `zipro_website_new/src/assets/logo.png`.
class ZiproLogoPng extends StatelessWidget {
  const ZiproLogoPng({
    super.key,
    this.height = 48,
    this.alignment = Alignment.center,
  });

  final double height;
  final AlignmentGeometry alignment;

  static const assetPath = 'assets/branding/logo.png';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Image.asset(
        assetPath,
        height: height,
        fit: BoxFit.contain,
      ),
    );
  }
}

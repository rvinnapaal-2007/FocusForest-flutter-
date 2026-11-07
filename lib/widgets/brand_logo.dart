import 'package:flutter/material.dart';
import '../config/app_config.dart';

/// The Focus Forest wordmark (your logo, unchanged) shown on a soft light plate
/// so the dark-green lettering stays readable on the dark forest theme.
class FocusForestLogo extends StatelessWidget {
  final double height;
  final double radius;
  const FocusForestLogo({super.key, this.height = 56, this.radius = 14});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        color: Colors.white,
        child: Image.asset(
          AppConfig.logoAsset,
          height: height,
          fit: BoxFit.contain,
          semanticLabel: AppConfig.appName,
        ),
      ),
    );
  }
}

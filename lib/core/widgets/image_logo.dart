import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import '../constants/app_colors.dart';

enum AcademyLogoVariant {
  full,
  mark,
}

class AcademyLogo extends StatelessWidget {
  const AcademyLogo({
    super.key,
    this.variant = AcademyLogoVariant.full,
    this.logoWidth = 128,
    this.logoHeight,
    this.cardSize,
    this.showCard = true,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = 28,
  });

  final AcademyLogoVariant variant;
  final double logoWidth;
  final double? logoHeight;
  final double? cardSize;
  final bool showCard;
  final EdgeInsetsGeometry padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final String assetPath = variant == AcademyLogoVariant.full
        ? AppAssets.logo
        : AppAssets.logoMark;

    final Widget logo = Image.asset(
      assetPath,
      width: logoWidth,
      height: logoHeight,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );

    if (!showCard) {
      return logo;
    }

    return Container(
      width: cardSize,
      height: cardSize,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface.withOpacity(0.92),
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: AppColors.border.withOpacity(0.85),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Center(child: logo),
    );
  }
}
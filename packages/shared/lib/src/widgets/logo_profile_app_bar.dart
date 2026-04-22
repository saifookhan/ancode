import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Thin top row: mark logo (left), circular profile outline (right).
class LogoProfileAppBar extends StatelessWidget {
  const LogoProfileAppBar({
    super.key,
    this.logoAssetPath = 'assets/logo.png',
    this.logoSize = 40,
    this.profileIconSize = 24,
    this.ringSize = 42,
    this.onProfileTap,
    this.padding = const EdgeInsets.fromLTRB(20, 8, 20, 12),
  });

  final String logoAssetPath;
  final double logoSize;
  final double profileIconSize;
  final double ringSize;
  final VoidCallback? onProfileTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ring = Container(
      width: ringSize,
      height: ringSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.bluUniversoDeep, width: 1.8),
        color: AppColors.biancoOttico,
      ),
      child: Icon(
        Icons.person_outline_rounded,
        color: AppColors.bluUniversoDeep,
        size: profileIconSize,
      ),
    );

    final profileControl = onProfileTap == null
        ? ring
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onProfileTap,
              customBorder: const CircleBorder(),
              child: ring,
            ),
          );

    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Image.asset(
            logoAssetPath,
            width: logoSize,
            height: logoSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.star_rounded, size: logoSize * 0.9, color: AppColors.azzurroCiano),
          ),
          profileControl,
        ],
      ),
    );
  }
}

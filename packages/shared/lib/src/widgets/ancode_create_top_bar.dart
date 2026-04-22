import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Narrow strip with white mark (Crea screen header); defaults to same fill as the Crea body ([AppColors.bluUniverso]).
class AncodeCreateTopBar extends StatelessWidget {
  const AncodeCreateTopBar({
    super.key,
    this.logoAssetPath = 'assets/logo.png',
    this.height = 52,
    this.logoHeight = 30,
    this.backgroundColor = AppColors.bluUniverso,
    this.horizontalPadding = 18,
  });

  final String logoAssetPath;
  final double height;
  final double logoHeight;
  final Color backgroundColor;
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Align(
            alignment: Alignment.centerLeft,
            child: ColorFiltered(
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              child: Image.asset(
                logoAssetPath,
                height: logoHeight,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Text(
                  '*',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: logoHeight * 1.1,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AncodeLogo extends StatelessWidget {
  const AncodeLogo({
    super.key,
    this.size = 80,
    this.showName = true,
  });

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '*',
          style: TextStyle(
            fontSize: size,
            height: 1,
            color: AppColors.azzurroCiano,
            fontWeight: FontWeight.w300,
            fontFamily: 'Outfit',
          ),
        ),
        if (showName) ...[
          const SizedBox(height: 8),
          Text(
            'ANCODE',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.bluUniverso,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
          ),
        ],
      ],
    );
  }
}

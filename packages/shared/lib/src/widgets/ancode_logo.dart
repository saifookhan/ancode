import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AncodeLogo extends StatelessWidget {
  const AncodeLogo({
    super.key,
    this.size = 80,
    this.showName = true,
    /// Optional asset path (e.g. 'assets/logo.png') – when set, shows image instead of asterisk
    this.logoAssetPath,
  });

  final double size;
  final bool showName;
  final String? logoAssetPath;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logoAssetPath != null)
          Image.asset(
            logoAssetPath!,
            width: size,
            height: size,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => _asteriskWidget(),
          )
        else
          _asteriskWidget(),
        if (showName) ...[
          const SizedBox(height: 8),
          Text(
            'ANCODE',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: AppColors.bluPolvere,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
          ),
        ],
      ],
    );
  }

  Widget _asteriskWidget() {
    return Text(
      '*',
      style: TextStyle(
        fontSize: size,
        height: 1,
        color: AppColors.azzurroCiano,
        fontWeight: FontWeight.w300,
      ),
    );
  }
}

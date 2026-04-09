import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class AncodeLogo extends StatelessWidget {
  const AncodeLogo({
    super.key,
    this.size = 80,
    this.showName = true,
    /// Optional asset path (e.g. 'assets/logo.png') – when set, shows image instead of asterisk
    this.logoAssetPath,
    /// Shown between the mark and “ANCODE” (e.g. landing “CERCA O CREA”)
    this.subtitle,
    this.subtitleFontSize,
    this.nameColor,
    this.nameFontSize,
  });

  final double size;
  final bool showName;
  final String? logoAssetPath;
  final String? subtitle;
  final double? subtitleFontSize;
  final Color? nameColor;
  final double? nameFontSize;

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
          SizedBox(height: subtitle != null && subtitle!.isNotEmpty ? 16 : 8),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w800,
                fontSize: subtitleFontSize ?? 15,
                letterSpacing: subtitleFontSize != null ? 2.4 : 1.4,
                height: 1.1,
              ),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            'ANCODE',
            style: TextStyle(
              color: nameColor ?? AppColors.bluPolvere,
              fontWeight: FontWeight.w700,
              fontSize: nameFontSize ?? Theme.of(context).textTheme.headlineLarge?.fontSize ?? 32,
              letterSpacing: nameFontSize != null ? 4 : 2,
              height: 1.05,
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

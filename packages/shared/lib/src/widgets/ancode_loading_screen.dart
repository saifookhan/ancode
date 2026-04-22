import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Blank white screen with the mark logo rotating about its center (startup / auth idle).
class AncodeLoadingScreen extends StatefulWidget {
  const AncodeLoadingScreen({
    super.key,
    this.logoAssetPath = 'assets/logo.png',
    this.logoSize = 140,
    this.duration = const Duration(milliseconds: 2200),
    this.backgroundColor = AppColors.biancoOttico,
  });

  final String logoAssetPath;
  final double logoSize;
  final Duration duration;
  final Color backgroundColor;

  @override
  State<AncodeLoadingScreen> createState() => _AncodeLoadingScreenState();
}

class _AncodeLoadingScreenState extends State<AncodeLoadingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.backgroundColor,
      body: Center(
        child: RotationTransition(
          turns: _controller,
          child: Image.asset(
            widget.logoAssetPath,
            width: widget.logoSize,
            height: widget.logoSize,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(Icons.star_rounded, size: widget.logoSize * 0.85, color: AppColors.azzurroCiano),
          ),
        ),
      ),
    );
  }
}

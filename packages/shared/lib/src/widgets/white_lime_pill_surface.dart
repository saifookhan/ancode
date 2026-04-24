import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// White pill with navy stroke and a solid lime layer inset from the bottom-right (no blur),
/// matching the create-page / home “INSERISCI ANCODE” control.
///
/// When [width] is set and [width] == [height], corners are a perfect circle (nav dots).
///
/// Set [cornerRadius] for a rounded rectangle (e.g. note field on Crea); omit for pill/stadium.
class WhiteLimePillSurface extends StatelessWidget {
  const WhiteLimePillSurface({
    super.key,
    required this.child,
    /// Total control height (face + visible lime band).
    this.height = 52,
    /// When set with the same value as [height], the control is circular (nav).
    this.width,
    this.shadowDepth = 8,
    this.borderWidth = 1.5,
    this.outlineColor,
    this.railColor,
    this.extrusionDx = 0,
    this.depthOutlined = false,
    /// Face fill; default [AppColors.biancoOttico] (e.g. navy when selected on nav).
    this.faceColor,
    /// Fixed corner radius (px); ignored when [width] == [height] (nav circles).
    this.cornerRadius,
  });

  final Widget child;
  final double height;
  final double? width;
  final double shadowDepth;
  final double borderWidth;
  final Color? outlineColor;
  final Color? railColor;
  final double extrusionDx;
  final bool depthOutlined;
  final Color? faceColor;
  final double? cornerRadius;

  Color get _outline => outlineColor ?? AppColors.bluUniversoDeep;

  bool get _circularFixed => width != null && width == height;

  bool get _roundedRect =>
      cornerRadius != null && cornerRadius! > 0 && !_circularFixed;

  BorderRadius get _outerRadius {
    if (_circularFixed) {
      return BorderRadius.circular(width! / 2);
    }
    if (_roundedRect) {
      return BorderRadius.circular(cornerRadius!);
    }
    return BorderRadius.circular(999);
  }

  BorderRadius _innerRadius() {
    if (_circularFixed) {
      final iw = width! - extrusionDx;
      final ih = height - shadowDepth;
      final r = math.max(0.0, math.min(iw, ih) / 2 - 0.5);
      return BorderRadius.circular(r);
    }
    if (_roundedRect) {
      // Same radius as outer so lime rail, face, and field paint align (no pill “cap” inside a rect).
      return BorderRadius.circular(cornerRadius!);
    }
    return BorderRadius.circular(999);
  }

  BorderRadius _clipRadius() {
    if (_circularFixed) {
      final iw = width! - extrusionDx;
      final ih = height - shadowDepth;
      final r = math.max(0.0, math.min(iw, ih) / 2 - 1);
      return BorderRadius.circular(r);
    }
    if (_roundedRect) {
      return BorderRadius.circular(cornerRadius!);
    }
    return BorderRadius.circular(960);
  }

  @override
  Widget build(BuildContext context) {
    final rail = railColor ?? AppColors.limeCreateHard;
    final face = faceColor ?? AppColors.biancoOttico;
    final innerR = _innerRadius();
    final clipR = _clipRadius();

    return SizedBox(
      width: width ?? double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: rail,
              borderRadius: _outerRadius,
              border: depthOutlined
                  ? Border.all(color: _outline, width: borderWidth)
                  : null,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, extrusionDx, shadowDepth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: face,
                borderRadius: innerR,
                border: Border.all(color: _outline, width: borderWidth),
              ),
              child: ClipRRect(
                borderRadius: clipR,
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

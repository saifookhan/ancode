import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// White pill CTA with hard lime “rail” (optional bottom-right extrusion like [WhiteLimePillSurface]).
class WhiteLimePillButton extends StatelessWidget {
  const WhiteLimePillButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.loading = false,
    this.height = 58,
    this.shadowDepth = 8,
    this.fontSize = 18,
    this.extrusionDx = 0,
    this.railColor,
    this.outlineColor,
    this.depthOutlined = false,
    this.borderWidth = 1.5,
    this.labelColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;
  final double height;
  final double shadowDepth;
  final double fontSize;
  final double extrusionDx;
  final Color? railColor;
  final Color? outlineColor;
  final bool depthOutlined;
  final double borderWidth;
  final Color? labelColor;

  static const Color _defaultOutline = AppColors.bluUniversoDeep;

  @override
  Widget build(BuildContext context) {
    final busy = loading;
    final effectiveOnTap = (onPressed == null || busy) ? null : onPressed;
    final rail = railColor ?? AppColors.limeCreateHard;
    final outline = outlineColor ?? _defaultOutline;
    final textColor = labelColor ?? outline;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: rail,
              borderRadius: BorderRadius.circular(999),
              border: depthOutlined
                  ? Border.all(color: outline, width: borderWidth)
                  : null,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, extrusionDx, shadowDepth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.biancoOttico,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: outline, width: borderWidth),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: effectiveOnTap,
                  splashColor: AppColors.bluUniverso.withOpacity(0.08),
                  highlightColor: AppColors.bluUniverso.withOpacity(0.05),
                  child: Center(
                    child: busy
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: outline,
                            ),
                          )
                        : Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              fontWeight: FontWeight.w800,
                              fontSize: fontSize,
                              color: textColor,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// Lime pill, navy label and stroke, hard lime shadow rail (e.g. “Vai al contenuto”).
class LimeFacePillButton extends StatelessWidget {
  const LimeFacePillButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.loading = false,
    this.height = 58,
    this.shadowDepth = 8,
    this.fontSize = 18,
    this.faceColor,
    this.shadowFaceColor,
    this.showOutline = true,
    this.labelColor,
    this.extrusionDx = 0,
    this.depthOutlined = false,
    this.outlineColor,
    this.outlineWidth = 1.5,
    this.depthOutlineColor,
    this.depthOutlineWidth = 1.5,
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;
  final double height;
  final double shadowDepth;
  final double fontSize;
  final Color? faceColor;
  /// Lime layer behind the face (extrusion). When null, matches [faceColor] default.
  final Color? shadowFaceColor;
  final bool showOutline;
  final Color? labelColor;
  final double extrusionDx;
  final bool depthOutlined;
  /// Face stroke color when [showOutline] is true.
  final Color? outlineColor;
  final double outlineWidth;
  final Color? depthOutlineColor;
  final double depthOutlineWidth;

  static const Color _defaultOutline = AppColors.bluUniversoDeep;

  @override
  Widget build(BuildContext context) {
    final busy = loading;
    final effectiveOnTap = (onPressed == null || busy) ? null : onPressed;
    final face = faceColor ?? AppColors.limeCreateHard;
    final rail = shadowFaceColor ?? face;
    final textColor = labelColor ?? _defaultOutline;
    final stroke = outlineColor ?? _defaultOutline;
    final faceBorder =
        showOutline ? Border.all(color: stroke, width: outlineWidth) : null;
    final depthBorder = depthOutlined
        ? Border.all(
            color: depthOutlineColor ?? stroke,
            width: depthOutlineWidth,
          )
        : null;

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
              border: depthBorder,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, extrusionDx, shadowDepth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: face,
                borderRadius: BorderRadius.circular(999),
                border: faceBorder,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: effectiveOnTap,
                  splashColor: AppColors.bluUniverso.withOpacity(0.12),
                  highlightColor: AppColors.bluUniverso.withOpacity(0.06),
                  child: Center(
                    child: busy
                        ? SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: textColor,
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

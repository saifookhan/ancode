import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// Pill button: dark body, white label, lime band at bottom, black outer stroke
/// (matches the reference “CERCA” control).
class LimeRailPillButton extends StatelessWidget {
  const LimeRailPillButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.leadingIcon,
    this.loading = false,
    this.height = 58,
    this.shadowDepth = 8,
    this.fontSize = 18,
    this.fillColor,
    this.shadowFaceColor,
    this.extrusionDx = 0,
    this.depthOutlined = false,
    this.faceBorderColor,
    this.faceBorderWidth = 1.5,
    this.depthBorderColor,
    this.depthBorderWidth = 1.5,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? leadingIcon;
  final bool loading;
  final double height;
  final double shadowDepth;
  final double fontSize;
  /// When null, uses default navy rail fill.
  final Color? fillColor;
  /// When null, uses default lime extrusion layer.
  final Color? shadowFaceColor;
  final double extrusionDx;
  final bool depthOutlined;
  /// Stroke around the top (face) pill; null keeps previous look (no stroke).
  final Color? faceBorderColor;
  final double faceBorderWidth;
  /// Stroke on lime depth when [depthOutlined] is true; defaults to [faceBorderColor].
  final Color? depthBorderColor;
  final double depthBorderWidth;

  static const Color _defaultNavy = Color(0xFF16004F);
  static const Color _defaultLime = AppColors.limeCreateHard;

  @override
  Widget build(BuildContext context) {
    final busy = loading;
    final effectiveOnTap = (onPressed == null || busy) ? null : onPressed;

    final navy = fillColor ?? _defaultNavy;
    final lime = shadowFaceColor ?? _defaultLime;
    final depthBorder = depthOutlined
        ? Border.all(
            color: depthBorderColor ?? faceBorderColor ?? const Color(0xFF000000),
            width: depthBorderWidth,
          )
        : null;
    final faceBorder = faceBorderColor != null
        ? Border.all(color: faceBorderColor!, width: faceBorderWidth)
        : null;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: lime,
              border: depthBorder,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, extrusionDx, shadowDepth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: navy,
                borderRadius: BorderRadius.circular(999),
                border: faceBorder,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: effectiveOnTap,
                  splashColor: Colors.white24,
                  highlightColor: Colors.white10,
                  child: Center(
                    child: busy
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                          )
                        : Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (leadingIcon != null) ...[
                                Icon(leadingIcon, color: Colors.white, size: fontSize + 2),
                                const SizedBox(width: 8),
                              ],
                              Text(
                                label,
                                style: TextStyle(
                                  fontFamily: AppFonts.family,
                                  fontWeight: FontWeight.w800,
                                  fontSize: fontSize,
                                  color: Colors.white,
                                  letterSpacing: 0.6,
                                ),
                              ),
                            ],
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

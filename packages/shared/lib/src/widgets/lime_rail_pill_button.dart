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
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? leadingIcon;
  final bool loading;
  final double height;
  final double shadowDepth;
  final double fontSize;

  static const Color _navy = Color(0xFF16004F);
  static const Color _lime = AppColors.limeCreateHard;

  @override
  Widget build(BuildContext context) {
    final busy = loading;
    final effectiveOnTap = (onPressed == null || busy) ? null : onPressed;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: _lime,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, shadowDepth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.circular(999),
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

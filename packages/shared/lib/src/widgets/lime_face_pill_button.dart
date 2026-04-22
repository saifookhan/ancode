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
  });

  final VoidCallback? onPressed;
  final String label;
  final bool loading;
  final double height;
  final double shadowDepth;
  final double fontSize;

  static const Color _outline = AppColors.bluUniversoDeep;

  @override
  Widget build(BuildContext context) {
    final busy = loading;
    final effectiveOnTap = (onPressed == null || busy) ? null : onPressed;

    return SizedBox(
      width: double.infinity,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.limeCreateHard,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(0, 0, 0, shadowDepth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.limeCreateHard,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _outline, width: 1.5),
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
                              color: _outline,
                            ),
                          )
                        : Text(
                            label,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: AppFonts.family,
                              fontWeight: FontWeight.w800,
                              fontSize: fontSize,
                              color: _outline,
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

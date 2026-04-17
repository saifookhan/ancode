import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// White pill with navy stroke and a solid lime layer inset from the bottom (no blur),
/// matching the create-page field / control reference.
class WhiteLimePillSurface extends StatelessWidget {
  const WhiteLimePillSurface({
    super.key,
    required this.child,
    /// Total control height (face + visible lime band), same pattern as [WhiteLimePillButton].
    this.height = 52,
    this.shadowDepth = 8,
    this.borderWidth = 1.5,
  });

  final Widget child;
  final double height;
  final double shadowDepth;
  final double borderWidth;

  static const Color _outline = AppColors.bluUniversoDeep;

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.biancoOttico,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: _outline, width: borderWidth),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(960),
                child: child,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

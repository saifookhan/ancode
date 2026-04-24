import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';
import 'white_lime_pill_surface.dart';

/// Bottom navigation: Crea, Dashboard, Home, Chatbot, Profilo.
/// Each tab uses the same neo-brut surface as home “INSERISCI ANCODE” ([WhiteLimePillSurface]),
/// with a circular footprint (width == height).
class AncodeBottomNavBar extends StatelessWidget {
  const AncodeBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.add_circle_outline_rounded, label: 'Crea'),
    _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    _NavItem(icon: Icons.home_outlined, label: 'Home'),
    _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chatbot'),
    _NavItem(icon: Icons.person_outline_rounded, label: 'Profilo'),
  ];

  static const double _bubbleSize = 64;
  static const Color _ink = AppColors.slateNavy;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final safeBottomPadding = (bottomInset - 6).clamp(0.0, double.infinity).toDouble();
    final bottomMargin = bottomInset > 0 ? 0.0 : 12.0;

    return Padding(
      padding: EdgeInsets.only(bottom: safeBottomPadding),
      child: Container(
        margin: EdgeInsets.fromLTRB(14, 0, 14, bottomMargin),
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
        decoration: BoxDecoration(
          color: AppColors.biancoOttico,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: const Color(0xFFE4E4EB), width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: _bubbleSize + 2,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotW = constraints.maxWidth / _items.length;
              return Row(
                mainAxisSize: MainAxisSize.max,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: List.generate(_items.length, (i) {
                  final item = _items[i];
                  final selected = i == currentIndex;
                  return SizedBox(
                    width: slotW,
                    height: _bubbleSize + 2,
                    child: Material(
                      type: MaterialType.transparency,
                      child: InkWell(
                        onTap: () => onTap(i),
                        borderRadius: BorderRadius.circular(999),
                        splashFactory: InkRipple.splashFactory,
                        child: Center(
                          child: WhiteLimePillSurface(
                            width: _bubbleSize,
                            height: _bubbleSize,
                            shadowDepth: 8,
                            extrusionDx: 4,
                            borderWidth: 1.5,
                            outlineColor: AppColors.slateNavy,
                            railColor: AppColors.limeMockup,
                            depthOutlined: true,
                            faceColor:
                                selected ? AppColors.slateNavy : AppColors.biancoOttico,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 20,
                                      color: selected
                                          ? AppColors.biancoOttico
                                          : _ink,
                                    ),
                                    const SizedBox(height: 2),
                                    SizedBox(
                                      width: _bubbleSize - 8,
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.center,
                                        child: Text(
                                          item.label,
                                          maxLines: 1,
                                          style: TextStyle(
                                            fontFamily: AppFonts.family,
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w600,
                                            height: 1.05,
                                            color: selected
                                                ? AppColors.biancoOttico
                                                : _ink,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

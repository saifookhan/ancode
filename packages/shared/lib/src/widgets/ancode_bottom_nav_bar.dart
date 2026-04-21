import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_fonts.dart';

/// Primary app navigation: Home, Dashboard, Crea, Chatbot, Profilo.
/// Single implementation shared by mobile and web so tabs stay in sync.
class AncodeBottomNavBar extends StatelessWidget {
  const AncodeBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_outlined, label: 'Home'),
    _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
    _NavItem(icon: Icons.add_circle_outline_rounded, label: 'Crea'),
    _NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Chatbot'),
    _NavItem(icon: Icons.person_outline_rounded, label: 'Profilo'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final bottomMargin = bottomInset > 0 ? 0.0 : 12.0;

    return SafeArea(
      top: false,
      child: Container(
        margin: EdgeInsets.fromLTRB(14, 0, 14, bottomMargin),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        decoration: BoxDecoration(
          color: AppColors.biancoOttico,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [
            BoxShadow(
              color: Color(0x22000000),
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        // Bounded height: a Column with mainAxisSize.max inside Row/Expanded can get
        // unbounded maxHeight from the bottomNavigationBar slot and break the scaffold
        // (body collapses, bar appears centered). Keep a fixed slot and center each item.
        child: SizedBox(
          height: 74,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_items.length, (i) {
              final item = _items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  borderRadius: BorderRadius.circular(28),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.bluUniverso : AppColors.biancoOttico,
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFDBDBE6)),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.limeNeobrut,
                                blurRadius: 0,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            item.icon,
                            size: 22,
                            color: selected ? AppColors.biancoOttico : AppColors.bluUniverso,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontFamily: AppFonts.family,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: selected ? AppColors.bluUniverso : AppColors.bluPolvere,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
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

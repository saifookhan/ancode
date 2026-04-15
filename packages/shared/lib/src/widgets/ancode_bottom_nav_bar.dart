import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Primary app navigation: History, Search, Create, Dashboard.
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
    _NavItem(icon: Icons.history_rounded, label: 'Cronologia'),
    _NavItem(icon: Icons.search_rounded, label: 'CERCA'),
    _NavItem(icon: Icons.add_circle_outline_rounded, label: 'CREA'),
    _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard'),
  ];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final selected = i == currentIndex;
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                borderRadius: BorderRadius.circular(28),
                child: Column(
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
            );
          }),
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

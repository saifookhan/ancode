import 'package:flutter/material.dart';

import 'package:shared/shared.dart';

/// Modern curved pill bottom nav: white bar, 5 items in circles with lime green border.
class AncodeBottomNavBar extends StatelessWidget {
  const AncodeBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.history, label: 'History'),
    _NavItem(icon: Icons.add_circle_outline, label: 'Create'),
    _NavItem(icon: Icons.search, label: 'Search'),
    _NavItem(icon: Icons.dashboard_outlined, label: 'Codes'),
    _NavItem(icon: Icons.chat_bubble_outline, label: 'Chatbot'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.biancoOttico,
        borderRadius: BorderRadius.circular(1000),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.bluUniverso : AppColors.biancoOttico,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.verdeCosmico,
                        width: 2,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.verdeCosmico.withOpacity(0.5),
                                blurRadius: 8,
                                spreadRadius: 0,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      item.icon,
                      size: 22,
                      color: selected ? AppColors.biancoOttico : AppColors.bluPolvere,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      color: selected ? AppColors.biancoOttico : AppColors.bluPolvere,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

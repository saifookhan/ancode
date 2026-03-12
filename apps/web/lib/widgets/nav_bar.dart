import 'package:flutter/material.dart';

import 'package:shared/shared.dart';

/// Same as mobile: curved pill, margin 10, labels History, Create, Search, Codes, Chatbot.
class NavBar extends StatelessWidget implements PreferredSizeWidget {
  const NavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    (icon: Icons.history, label: 'History'),
    (icon: Icons.add_circle_outline, label: 'Create'),
    (icon: Icons.search, label: 'Search'),
    (icon: Icons.dashboard_outlined, label: 'Codes'),
    (icon: Icons.chat_bubble_outline, label: 'Chatbot'),
  ];

  @override
  Size get preferredSize => const Size.fromHeight(80);

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
        children: List.generate(
          _items.length,
          (i) => _NavItem(
            icon: _items[i].icon,
            label: _items[i].label,
            isSelected: currentIndex == i,
            onTap: () => onTap(i),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.bluUniverso : AppColors.biancoOttico,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.verdeCosmico, width: 2),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected ? AppColors.biancoOttico : AppColors.bluPolvere,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? AppColors.bluPolvere : AppColors.bluPolvere,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

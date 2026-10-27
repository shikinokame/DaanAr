import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';

/// Bottom navigation shell wrapping Home, Explore (Trails & Landmarks), and Map tabs,
/// styled after the Figma archival field-guide bottom bar.
class ShellScreen extends StatelessWidget {
  final Widget child;
  const ShellScreen({super.key, required this.child});

  static const _tabs = ['/home', '/trails', '/map'];

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    for (int i = 0; i < _tabs.length; i++) {
      if (location.startsWith(_tabs[i])) return i;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final index = _currentIndex(context);
    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.rule, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 68,
            child: Row(
              children: [
                _ArchivalNavItem(
                  label: 'Home',
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  selected: index == 0,
                  onTap: () => context.go(_tabs[0]),
                ),
                _ArchivalNavItem(
                  label: 'Explore',
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore_rounded,
                  selected: index == 1,
                  onTap: () => context.go(_tabs[1]),
                ),
                _ArchivalNavItem(
                  label: 'Map',
                  icon: Icons.map_outlined,
                  activeIcon: Icons.map_rounded,
                  selected: index == 2,
                  onTap: () => context.go(_tabs[2]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArchivalNavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final IconData activeIcon;
  final bool selected;
  final VoidCallback onTap;

  const _ArchivalNavItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Top antique-brass indicator bar on active tab (matches Figma)
            if (selected)
              Positioned(
                top: 0,
                child: Container(
                  width: 42,
                  height: 2.5,
                  color: AppColors.brassInk,
                ),
              ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.ink : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    selected ? activeIcon : icon,
                    size: 19,
                    color: selected ? AppColors.surface : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: AppFonts.serif,
                    fontSize: 13.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected ? AppColors.ink : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

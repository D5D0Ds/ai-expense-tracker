import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:ai_expense_tracker/shared/widgets/glass_panel.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

/// Main bottom-navigation shell.
class AppShell extends StatelessWidget {
  /// Creates the shell.
  const AppShell({required this.navigationShell, super.key});

  /// GoRouter nested shell.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return AppBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: navigationShell,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
            child: GlassPanel(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: LucideIcons.house,
                    label: 'Home',
                    selected: navigationShell.currentIndex == 0,
                    onPressed: () => navigationShell.goBranch(0),
                  ),
                  _NavItem(
                    icon: LucideIcons.receiptText,
                    label: 'Ledger',
                    selected: navigationShell.currentIndex == 1,
                    onPressed: () => navigationShell.goBranch(1),
                  ),
                  _NavItem(
                    icon: LucideIcons.chartNoAxesColumn,
                    label: 'Reports',
                    selected: navigationShell.currentIndex == 2,
                    onPressed: () => navigationShell.goBranch(2),
                  ),
                  _NavItem(
                    icon: LucideIcons.settings,
                    label: 'Settings',
                    selected: navigationShell.currentIndex == 3,
                    onPressed: () => navigationShell.goBranch(3),
                  ),
                ],
              ),
            ),
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
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppTheme.accentSoft : AppTheme.textMuted;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: selected ? AppTheme.accent : color),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                width: selected ? 18 : 4,
                height: 4,
                decoration: BoxDecoration(
                  color: selected
                      ? AppTheme.accent
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

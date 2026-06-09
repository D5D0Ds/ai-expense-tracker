import 'dart:ui';

import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Reusable premium glass surface.
class GlassPanel extends StatelessWidget {
  /// Creates a glass panel.
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.borderColor,
  });

  /// Panel content.
  final Widget child;

  /// Inner spacing.
  final EdgeInsetsGeometry padding;

  /// Outer spacing.
  final EdgeInsetsGeometry? margin;

  /// Optional tap handler.
  final VoidCallback? onTap;

  /// Optional custom border color.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    const radius = 28.0;
    final panel = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          margin: margin,
          padding: padding,
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? const Color(0xFF26303B),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 42,
                offset: const Offset(0, 22),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: panel,
      ),
    );
  }
}

/// Full-page dark backdrop with a pure, modern, classic layout.
class AppBackdrop extends StatelessWidget {
  /// Creates an app backdrop.
  const AppBackdrop({required this.child, super.key});

  /// Page content.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppTheme.background,
      ),
      child: child,
    );
  }
}

import 'dart:ui';

import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Reusable premium glass surface.
class GlassPanel extends StatelessWidget {
  /// Creates a glass panel.
  const GlassPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(18),
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
            color: AppTheme.surfaceRaised.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: borderColor ?? AppTheme.accentSoft.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.34),
                blurRadius: 42,
                offset: const Offset(0, 26),
              ),
              BoxShadow(
                color: AppTheme.accent.withValues(alpha: 0.06),
                blurRadius: 30,
                offset: const Offset(0, -8),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppTheme.accentSoft.withValues(alpha: 0.08),
                AppTheme.surfaceRaised.withValues(alpha: 0.88),
                AppTheme.surfaceMuted.withValues(alpha: 0.92),
              ],
            ),
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

/// Full-page dark backdrop with subtle depth and no decorative blobs.
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
        gradient: RadialGradient(
          center: Alignment.topCenter,
          radius: 1.35,
          colors: [
            Color(0xFF182214),
            Color(0xFF0B0E10),
            AppTheme.background,
            Color(0xFF020304),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -140,
            left: -80,
            right: -80,
            child: IgnorePointer(
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withValues(alpha: 0.14),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -180,
            right: -60,
            child: IgnorePointer(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.blue.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

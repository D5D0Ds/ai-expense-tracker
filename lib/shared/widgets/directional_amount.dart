import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/core/formatters.dart';
import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Modern fintech amount display with color-coded text and a filled
/// directional triangle instead of +/- signs.
///
/// Used across SMS suggestions, expense list, and detail screens.
class DirectionalAmount extends StatelessWidget {
  /// Creates a directional amount.
  const DirectionalAmount({
    required this.amount,
    required this.kind,
    this.size = DirectionalAmountSize.medium,
    this.currency,
    super.key,
  });

  /// Amount value.
  final double amount;

  /// Transaction kind that drives color and arrow direction.
  final TransactionKind kind;

  /// Visual size preset.
  final DirectionalAmountSize size;

  /// Optional override currency (defaults to INR).
  final String? currency;

  @override
  Widget build(BuildContext context) {
    final triangleColor = switch (kind) {
      TransactionKind.expense => AppTheme.coral,
      TransactionKind.lent => AppTheme.amber,
      TransactionKind.borrowed => AppTheme.turquoise,
    };

    final textColor = switch (kind) {
      TransactionKind.expense => Colors.white,
      TransactionKind.lent => Colors.white,
      TransactionKind.borrowed => AppTheme.turquoise,
    };

    final (arrowSize, fontSize, fontWeight, spacing) = switch (size) {
      DirectionalAmountSize.small => (7.0, 15.0, FontWeight.w800, 5.0),
      DirectionalAmountSize.medium => (9.0, 20.0, FontWeight.w900, 6.0),
      DirectionalAmountSize.large => (12.0, 36.0, FontWeight.w900, 8.0),
      DirectionalAmountSize.hero => (14.0, 42.0, FontWeight.w900, 10.0),
    };

    final formatted = currency == null
        ? inrFormat.format(amount)
        : NumberFormat.currency(
            locale: 'en_IN',
            symbol: currency,
            decimalDigits: 0,
          ).format(amount);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _FilledTriangle(
          size: arrowSize,
          color: triangleColor,
          direction: switch (kind) {
            TransactionKind.expense => _TriangleDirection.down,
            TransactionKind.lent => _TriangleDirection.upRight,
            TransactionKind.borrowed => _TriangleDirection.up,
          },
        ),
        SizedBox(width: spacing),
        Text(
          formatted,
          style: TextStyle(
            color: textColor,
            fontSize: fontSize,
            fontWeight: fontWeight,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// Size presets for [DirectionalAmount].
enum DirectionalAmountSize {
  /// Compact list-row size.
  small,

  /// Card and tile size.
  medium,

  /// Screen header size.
  large,

  /// Full-screen hero size.
  hero,
}

enum _TriangleDirection { up, down, upRight }

class _FilledTriangle extends StatelessWidget {
  const _FilledTriangle({
    required this.size,
    required this.color,
    required this.direction,
  });

  final double size;
  final Color color;
  final _TriangleDirection direction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _TrianglePainter(color: color, direction: direction),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  _TrianglePainter({required this.color, required this.direction});

  final Color color;
  final _TriangleDirection direction;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final w = size.width;
    final h = size.height;

    switch (direction) {
      case _TriangleDirection.up:
        path
          ..moveTo(w / 2, 0)
          ..lineTo(w, h)
          ..lineTo(0, h)
          ..close();
      case _TriangleDirection.down:
        path
          ..moveTo(0, 0)
          ..lineTo(w, 0)
          ..lineTo(w / 2, h)
          ..close();
      case _TriangleDirection.upRight:
        path
          ..moveTo(0, h)
          ..lineTo(w, 0)
          ..lineTo(w, h)
          ..close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) =>
      old.color != color || old.direction != direction;
}

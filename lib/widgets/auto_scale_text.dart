import 'dart:math';
import 'package:flutter/material.dart';

/// Text that shrinks its font to fit the available height (down to
/// [minFontSize]). If it still overflows at the minimum size, it becomes
/// vertically scrollable instead of being clipped.
///
/// With [expand] true (the default) the text is centered and fills the
/// available height — useful inside a bounded box like an [Expanded]. With
/// [expand] false it shrink-wraps to the text's own height, only shrinking once
/// it would exceed the maximum height imposed by the parent (e.g. a
/// [ConstrainedBox]); use this when the text should stay compact for short
/// content but scale down when space is tight.
class AutoScaleText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final bool expand;

  /// Font won't shrink below this before falling back to scrolling.
  static const double minFontSize = 16;

  const AutoScaleText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.center,
    this.expand = true,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ?? const TextStyle();
    final baseFontSize = baseStyle.fontSize ?? 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        double measuredHeight(double size) {
          final tp = TextPainter(
            text: TextSpan(
              text: text,
              style: baseStyle.copyWith(fontSize: size),
            ),
            textDirection: TextDirection.ltr,
            textAlign: textAlign,
          )..layout(maxWidth: constraints.maxWidth);
          return tp.height;
        }

        // Shrink one step at a time until it fits or we hit the floor.
        double fontSize = baseFontSize;
        while (fontSize > minFontSize &&
            measuredHeight(fontSize) > constraints.maxHeight) {
          fontSize = max(minFontSize, fontSize - 1);
        }

        final textWidget = Text(
          text,
          style: baseStyle.copyWith(fontSize: fontSize),
          textAlign: textAlign,
        );

        // Still too tall even at the smallest size → let the user scroll.
        if (measuredHeight(fontSize) > constraints.maxHeight) {
          return SingleChildScrollView(child: textWidget);
        }
        return expand ? Center(child: textWidget) : textWidget;
      },
    );
  }
}

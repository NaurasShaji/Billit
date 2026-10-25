import 'package:flutter/material.dart';

/// Shared breakpoints for layouts that adapt to phones, tablets and desktops.
abstract final class ResponsiveBreakpoints {
  static const double mobile = 600;
  static const double tablet = 900;
  static const double desktop = 1000;
}

/// Centers page content and prevents forms/lists from stretching too far on wide screens.
/// The child still receives the available height, so scrollable pages remain scrollable.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({
    super.key,
    required this.child,
    this.maxWidth = 1200,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Padding(
              padding: padding,
              child: SizedBox(
                width: double.infinity,
                height: double.infinity,
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}

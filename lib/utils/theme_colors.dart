import 'package:flutter/material.dart';

/// Theme-aware colours shared by screens with custom panel decorations.
extension ThemeColors on BuildContext {
  bool get isDarkTheme => Theme.of(this).brightness == Brightness.dark;

  Color get panelColor {
    final scheme = Theme.of(this).colorScheme;
    return isDarkTheme ? scheme.surfaceContainer : scheme.surface;
  }

  Color get subtleFill {
    final scheme = Theme.of(this).colorScheme;
    return isDarkTheme ? scheme.surfaceContainerHigh : scheme.surfaceContainerLow;
  }
}

extension AdaptiveColor on Color {
  Color adaptive(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Color.lerp(this, Colors.white, 0.4)!
          : this;
}

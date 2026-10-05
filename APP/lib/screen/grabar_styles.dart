import 'package:flutter/material.dart';

class GrabarStyles {
  static const Color primaryGreen = Color(0xff4f683c);
  static const Color primaryPink = Color(0xffec1768);

  static const EdgeInsets panelPadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
  static const EdgeInsets screenPadding = EdgeInsets.all(16);

  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(12),
  );

  static final ButtonStyle primaryButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: primaryGreen,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: buttonRadius),
  );

  static final ButtonStyle stopButtonStyle = ElevatedButton.styleFrom(
    backgroundColor: Colors.red.shade700,
    foregroundColor: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: buttonRadius),
  );

  static ButtonStyle secondaryButtonStyle(BuildContext context) =>
      ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: buttonRadius),
      );

  static TextStyle metricLabelStyle(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontSize: 11,
    fontWeight: FontWeight.w600,
  );

  static TextStyle metricValueStyle(BuildContext context) => TextStyle(
    color: Theme.of(context).colorScheme.onSurface,
    fontSize: 19,
    fontWeight: FontWeight.w700,
  );

  static TextStyle statusStyle(BuildContext context) =>
      TextStyle(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
        fontSize: 10,
      );

  static Widget currentLocationMarker({
    double size = 34,
    Color iconColor = const Color(0xff1d4ed8),
  }) {
    return Center(
      child: Icon(Icons.navigation, color: iconColor, size: size),
    );
  }
}

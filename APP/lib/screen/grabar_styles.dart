import 'package:flutter/material.dart';

class GrabarStyles {
  static const Color primaryGreen = Color(0xff4f683c);
  static const Color primaryPink = Color(0xffec1768);
  static const Color panelBackground = Color(0xfffbfaf7);

  static const EdgeInsets panelPadding = EdgeInsets.fromLTRB(16, 14, 16, 16);
  static const EdgeInsets screenPadding = EdgeInsets.all(16);

  static const BorderRadius buttonRadius = BorderRadius.all(
    Radius.circular(24),
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
  );

  static TextStyle metricLabelStyle(BuildContext context) => TextStyle(
    color: Colors.grey.shade600,
    fontSize: 9,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle metricValueStyle = TextStyle(
    color: Color(0xff171916),
    fontSize: 18,
    fontWeight: FontWeight.w700,
  );

  static TextStyle statusStyle(BuildContext context) =>
      TextStyle(color: Colors.grey.shade600, fontSize: 10);
}

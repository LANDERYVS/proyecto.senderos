import 'package:flutter/material.dart';

import '../screen/grabar_styles.dart';

class GrabarMetricIndicator extends StatelessWidget {
  const GrabarMetricIndicator({
    super.key,
    required this.label,
    required this.value,
    this.alignment = CrossAxisAlignment.start,
  });

  final String label;
  final String value;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          crossAxisAlignment: alignment,
          children: [
            Text(label, style: GrabarStyles.metricLabelStyle(context)),
            Text(value, style: GrabarStyles.metricValueStyle),
          ],
        ),
      ],
    );
  }
}

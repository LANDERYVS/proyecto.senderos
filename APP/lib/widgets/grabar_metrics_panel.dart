import 'package:flutter/material.dart';

import '../screen/grabar_styles.dart';
import 'grabar_metric_indicator.dart';

class GrabarMetricsPanel extends StatelessWidget {
  const GrabarMetricsPanel({
    super.key,
    required this.duration,
    required this.distanceKm,
    required this.elevationGainMeters,
    this.status,
    this.footer,
  });

  final String duration;
  final double distanceKm;
  final double elevationGainMeters;
  final String? status;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GrabarStyles.panelBackground,
      padding: GrabarStyles.panelPadding,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GrabarMetricIndicator(label: 'TIEMPO', value: duration),
              GrabarMetricIndicator(
                label: 'DISTANCIA',
                value: '${distanceKm.toStringAsFixed(1)} km',
                alignment: CrossAxisAlignment.end,
              ),
              GrabarMetricIndicator(
                label: 'SUBIDA',
                value: '${elevationGainMeters.toStringAsFixed(0)} m',
                alignment: CrossAxisAlignment.end,
              ),
            ],
          ),
          if (status != null) ...[
            const SizedBox(height: 5),
            Text(
              status!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GrabarStyles.statusStyle(context),
            ),
          ],
          if (footer != null) ...[const SizedBox(height: 12), footer!],
        ],
      ),
    );
  }
}

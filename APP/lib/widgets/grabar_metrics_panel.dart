import 'package:flutter/material.dart';

import '../screen/grabar_styles.dart';
import 'grabar_action_button.dart';
import 'grabar_metric_indicator.dart';

class GrabarMetricsPanel extends StatelessWidget {
  const GrabarMetricsPanel({
    super.key,
    required this.duration,
    required this.distanceKm,
    required this.elevationGainMeters,
    this.isPaused = false,
    this.isRecording = false,
    this.status,
    this.statusLabel = 'GRABANDO',
    this.onStart,
    this.onTogglePause,
    this.onStop,
    this.stopLabel = 'Detener',
  });

  final String duration;
  final double distanceKm;
  final double elevationGainMeters;
  final bool isPaused;
  final bool isRecording;
  final String? status;
  final String statusLabel;
  final VoidCallback? onStart;
  final VoidCallback? onTogglePause;
  final VoidCallback? onStop;
  final String stopLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GrabarStyles.panelBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      padding: GrabarStyles.panelPadding,
      child: Column(
        children: [
          if (status != null) ...[
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPaused ? Colors.orange.shade700 : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isPaused ? 'PAUSADO' : statusLabel,
                  style: TextStyle(
                    color: isPaused
                        ? Colors.orange.shade800
                        : Colors.red.shade700,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: GrabarStyles.statusStyle(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
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
          if (isRecording && (onTogglePause != null || onStop != null)) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (onTogglePause != null)
                  Expanded(
                    child: GrabarActionButton(
                      isRecording: true,
                      onPressed: onTogglePause!,
                      label: isPaused ? 'Reanudar' : 'Pausar',
                      icon: isPaused ? Icons.play_arrow : Icons.pause,
                      style: GrabarStyles.secondaryButtonStyle,
                    ),
                  ),
                if (onTogglePause != null && onStop != null)
                  const SizedBox(width: 8),
                if (onStop != null)
                  Expanded(
                    child: GrabarActionButton(
                      isRecording: true,
                      onPressed: onStop!,
                      label: stopLabel,
                      icon: Icons.stop,
                      style: GrabarStyles.stopButtonStyle,
                    ),
                  ),
              ],
            ),
          ] else if (!isRecording && onStart != null) ...[
            const SizedBox(height: 12),
            GrabarActionButton(
              isRecording: false,
              onPressed: onStart!,
              label: 'Iniciar trayecto',
              icon: Icons.play_arrow,
              style: GrabarStyles.primaryButtonStyle,
            ),
          ],
        ],
      ),
    );
  }
}

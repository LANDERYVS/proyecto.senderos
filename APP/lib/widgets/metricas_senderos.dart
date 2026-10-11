import 'package:flutter/material.dart';

import '../screen/grabar_styles.dart';
import 'grabar_action_button.dart';

// Panel con el tiempo, la distancia, el desnivel y los controles del trayecto.
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
    final colors = Theme.of(context).colorScheme;
    // La tarjeta se apoya en la parte inferior y se adapta al tema de la app.
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(top: BorderSide(color: colors.outlineVariant)),
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
          // Muestra si el trayecto está activo o pausado, junto con su estado actual.
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
              // Resume las tres métricas principales del trayecto.
              _GrabarMetricIndicator(label: 'TIEMPO', value: duration),
              _GrabarMetricIndicator(
                label: 'DISTANCIA',
                value: '${distanceKm.toStringAsFixed(1)} km',
                alignment: CrossAxisAlignment.end,
              ),
              _GrabarMetricIndicator(
                label: 'SUBIDA',
                value: '${elevationGainMeters.toStringAsFixed(0)} m',
                alignment: CrossAxisAlignment.end,
              ),
            ],
          ),
          // Durante la grabación ofrece pausar/reanudar y detener el trayecto.
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
                      style: GrabarStyles.secondaryButtonStyle(context),
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
            // Si todavía no se graba, muestra el botón para iniciar.
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

// Muestra una etiqueta y su valor, como "DISTANCIA" y "2.4 km".
class _GrabarMetricIndicator extends StatelessWidget {
  const _GrabarMetricIndicator({
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
            Text(value, style: GrabarStyles.metricValueStyle(context)),
          ],
        ),
      ],
    );
  }
}

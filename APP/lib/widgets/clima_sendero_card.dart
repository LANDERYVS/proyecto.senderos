import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../models/clima_sendero.dart';

class ClimaSenderoCard extends StatelessWidget {
  const ClimaSenderoCard({
    super.key,
    required this.isLoading,
    required this.hasRoute,
    required this.weather,
    required this.location,
    required this.onRefresh,
  });

  final bool isLoading;
  final bool hasRoute;
  final ClimaSendero? weather;
  final LatLng? location;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    if (isLoading && weather == null) {
      return const SizedBox(
        height: 80,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (!hasRoute || location == null) {
      return const _WeatherMessage(
        icon: Icons.location_off_outlined,
        message: 'No hay puntos GPX para ubicar el clima.',
      );
    }
    if (weather == null) {
      return _WeatherMessage(
        icon: Icons.cloud_off_outlined,
        message: 'No se pudo cargar el clima. Toca para reintentar.',
        onRetry: onRefresh,
      );
    }

    final currentWeather = weather!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_weatherIcon(currentWeather.code), size: 30),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${currentWeather.temperature.round()} °C',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(_weatherDescription(currentWeather.code)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Actualizar clima',
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _WeatherMetric(
                icon: Icons.thermostat,
                label:
                    'Sensación ${currentWeather.apparentTemperature.round()} °C',
              ),
              _WeatherMetric(
                icon: Icons.water_drop_outlined,
                label: 'Humedad ${currentWeather.humidity.round()}%',
              ),
              _WeatherMetric(
                icon: Icons.umbrella_outlined,
                label:
                    'Lluvia ${currentWeather.precipitation.toStringAsFixed(1)} mm',
              ),
              _WeatherMetric(
                icon: Icons.air,
                label: 'Viento ${currentWeather.windSpeed.round()} km/h',
              ),
            ],
          ),
          const SizedBox(height: 8),
          Divider(color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 2),
          Text(
            'Por días',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final day in currentWeather.dailyForecast)
                  _DailyForecastItem(
                    forecast: day,
                    isToday: day.date == currentWeather.currentLocalDate,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _weatherDescription(int code) {
    if (code == 0) return 'Despejado';
    if (code <= 3) return 'Parcialmente nublado';
    if (code <= 48) return 'Niebla';
    if (code <= 67 || (code >= 80 && code <= 82)) return 'Lluvia';
    if (code <= 77 || (code >= 85 && code <= 86)) return 'Nieve';
    if (code >= 95) return 'Tormenta';
    return 'Nublado';
  }
}

class _WeatherMessage extends StatelessWidget {
  const _WeatherMessage({
    required this.icon,
    required this.message,
    this.onRetry,
  });

  final IconData icon;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(message)),
          if (onRetry != null)
            IconButton(
              tooltip: 'Reintentar',
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
            ),
        ],
      ),
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _DailyForecastItem extends StatelessWidget {
  const _DailyForecastItem({required this.forecast, required this.isToday});

  final PronosticoClimaDiario forecast;
  final bool isToday;

  static const _weekdays = ['lun', 'mar', 'mié', 'jue', 'vie', 'sáb', 'dom'];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final date = DateTime.parse(forecast.date);
    final dayLabel = isToday ? 'Hoy' : _weekdays[date.weekday - 1];

    return SizedBox(
      width: 50,
      child: Column(
        children: [
          Text(
            dayLabel,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isToday ? colors.primary : null,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Icon(
            _weatherIcon(forecast.code),
            size: 22,
            color: isToday ? colors.primary : colors.onSurfaceVariant,
          ),
          const SizedBox(height: 6),
          Text(
            '${forecast.maximumTemperature.round()}°',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '${forecast.minimumTemperature.round()}°',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.water_drop, size: 12, color: colors.primary),
              const SizedBox(width: 2),
              Text(
                '${forecast.precipitationProbability.round()}%',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
          if (isToday)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Container(
                width: 16,
                height: 3,
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

IconData _weatherIcon(int code) {
  if (code == 0) return Icons.sunny;
  if (code <= 3) return Icons.wb_cloudy;
  if (code <= 48) return Icons.foggy;
  if (code <= 67 || (code >= 80 && code <= 82)) return Icons.umbrella;
  if (code <= 77 || (code >= 85 && code <= 86)) return Icons.ac_unit;
  if (code >= 95) return Icons.thunderstorm;
  return Icons.cloud_outlined;
}

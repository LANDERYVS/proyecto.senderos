import 'dart:convert';
import 'dart:io';

import 'package:latlong2/latlong.dart';

import '../models/clima_sendero.dart';

class ServicioClimaSendero {
  Future<ClimaSendero> obtenerClima(LatLng location) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.latitude.toString(),
      'longitude': location.longitude.toString(),
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,precipitation,wind_speed_10m,weather_code',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
      'forecast_days': '7',
      'timezone': 'auto',
    });
    final client = HttpClient();
    try {
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 12));
      final response = await request.close().timeout(
        const Duration(seconds: 12),
      );
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: uri);
      }

      final decoded = jsonDecode(
        await response
            .transform(const Utf8Decoder())
            .join()
            .timeout(const Duration(seconds: 12)),
      );
      if (decoded is! Map<String, dynamic> ||
          decoded['current'] is! Map<String, dynamic> ||
          decoded['daily'] is! Map<String, dynamic>) {
        throw const FormatException('La respuesta del clima no es válida.');
      }
      return ClimaSendero.fromJson(
        decoded['current'] as Map<String, dynamic>,
        decoded['daily'] as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }
}

class ClimaSendero {
  const ClimaSendero({
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.code,
    required this.currentLocalDate,
    required this.dailyForecast,
  });

  factory ClimaSendero.fromJson(
    Map<String, dynamic> current,
    Map<String, dynamic> daily,
  ) {
    final dates = _readList(daily, 'time');
    final maximums = _readList(daily, 'temperature_2m_max');
    final minimums = _readList(daily, 'temperature_2m_min');
    final probabilities = _readList(daily, 'precipitation_probability_max');
    final codes = _readList(daily, 'weather_code');
    if ([
      maximums,
      minimums,
      probabilities,
      codes,
    ].any((values) => values.length != dates.length)) {
      throw const FormatException('El pronóstico diario está incompleto.');
    }

    return ClimaSendero(
      temperature: _readNumber(current, 'temperature_2m'),
      apparentTemperature: _readNumber(current, 'apparent_temperature'),
      humidity: _readNumber(current, 'relative_humidity_2m'),
      precipitation: _readNumber(current, 'precipitation'),
      windSpeed: _readNumber(current, 'wind_speed_10m'),
      code: _readNumber(current, 'weather_code').toInt(),
      currentLocalDate: _readString(current, 'time').substring(0, 10),
      dailyForecast: List.generate(
        dates.length,
        (index) => PronosticoClimaDiario(
          date: dates[index] as String,
          maximumTemperature: _readListNumber(maximums[index]),
          minimumTemperature: _readListNumber(minimums[index]),
          precipitationProbability: _readListNumber(probabilities[index]),
          code: _readListNumber(codes[index]).toInt(),
        ),
      ),
    );
  }

  final double temperature;
  final double apparentTemperature;
  final double humidity;
  final double precipitation;
  final double windSpeed;
  final int code;
  final String currentLocalDate;
  final List<PronosticoClimaDiario> dailyForecast;
}

class PronosticoClimaDiario {
  const PronosticoClimaDiario({
    required this.date,
    required this.maximumTemperature,
    required this.minimumTemperature,
    required this.precipitationProbability,
    required this.code,
  });

  final String date;
  final double maximumTemperature;
  final double minimumTemperature;
  final double precipitationProbability;
  final int code;
}

double _readNumber(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) {
    throw FormatException('La respuesta del clima no contiene $key válido.');
  }
  return value.toDouble();
}

List<dynamic> _readList(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List<dynamic>) {
    throw FormatException('La respuesta del clima no contiene $key válido.');
  }
  return value;
}

double _readListNumber(Object? value) {
  if (value is! num) {
    throw const FormatException('Un valor del pronóstico diario no es válido.');
  }
  return value.toDouble();
}

String _readString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.length < 10) {
    throw FormatException('La respuesta del clima no contiene $key válido.');
  }
  return value;
}

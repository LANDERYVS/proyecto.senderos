import 'package:latlong2/latlong.dart';

class TrailWaypoint {
  const TrailWaypoint({required this.type, required this.point});

  static List<TrailWaypoint> fromMetadata(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('La lista de puntos de interés no es válida.');
    }
    return value.map((entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('El punto de interés no es válido.');
      }
      return TrailWaypoint.fromMap(entry);
    }).toList();
  }

  factory TrailWaypoint.fromMap(Map<String, dynamic> map) {
    final latitude = (map['lat'] as num?)?.toDouble();
    final longitude = (map['long'] as num?)?.toDouble();
    final type = map['type']?.toString().trim();
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        type == null ||
        type.isEmpty) {
      throw const FormatException('El punto de interés no es válido.');
    }
    return TrailWaypoint(
      type: type,
      point: LatLng(latitude, longitude),
    );
  }

  final String type;
  final LatLng point;

  Map<String, dynamic> toMap() => {
    'type': type,
    'lat': point.latitude,
    'long': point.longitude,
  };
}

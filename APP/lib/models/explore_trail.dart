class ExploreTrail {
  static const r2PublicBaseUrl = String.fromEnvironment(
    'R2_PUBLIC_BASE_URL',
    defaultValue: 'https://pub-a4c1361bdcbd4ab38809613ea21575c2.r2.dev',
  );

  const ExploreTrail({
    this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.distanceKm,
    required this.elevation,
    required this.author,
    this.photoUrl,
    this.gpxKey,
  });

  factory ExploreTrail.fromMap(
    Map<String, dynamic> map, {
    Map<String, String> userNames = const {},
  }) {
    final userId = map['user_id']?.toString() ?? 'Usuario desconocido';
    final name = map['sendero_nick']?.toString().trim() ?? '';
    final photo = publicR2Url(map['foto_sendero']?.toString());

    return ExploreTrail(
      id: (map['id'] as num?)?.toInt(),
      name: name.isEmpty ? 'Sendero sin nombre' : name,
      description: map['descripcion']?.toString() ?? '',
      difficulty: map['dificultad']?.toString() ?? 'Sin dificultad',
      distanceKm: (map['distancia'] as num?)?.toDouble() ?? 0,
      elevation: 'Desnivel no disponible',
      author: userNames[userId] ?? userId,
      photoUrl: photo,
      gpxKey: map['gpx_key']?.toString(),
    );
  }

  static String? publicR2Url(String? value) {
    if (value == null || value.isEmpty) return null;
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (r2PublicBaseUrl.isEmpty) return null;
    return '${r2PublicBaseUrl.replaceFirst(RegExp(r'/$'), '')}/'
        '${value.replaceFirst(RegExp(r'^/'), '')}';
  }

  final int? id;
  final String name;
  final String description;
  final String difficulty;
  final double distanceKm;
  final String elevation;
  final String author;
  final String? photoUrl;
  final String? gpxKey;

  String? get gpxUrl => publicR2Url(gpxKey);
}

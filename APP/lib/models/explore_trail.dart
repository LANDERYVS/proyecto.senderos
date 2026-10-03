class ExploreTrail {
  static const r2PublicBaseUrl = String.fromEnvironment(
    'R2_PUBLIC_BASE_URL',
    defaultValue: 'https://pub-a4c1361bdcbd4ab38809613ea21575c2.r2.dev',
  );

  const ExploreTrail({
    this.id,
    this.userId,
    required this.name,
    required this.description,
    required this.difficulty,
    this.sport = 'Sin especificar',
    required this.distanceKm,
    required this.elevation,
    required this.author,
    this.authorPhotoUrl,
    this.photoUrl,
    this.localPhotoPath,
    this.gpxKey,
  });

  factory ExploreTrail.fromMap(
    Map<String, dynamic> map, {
    Map<String, String> userNames = const {},
    Map<String, String> userPhotos = const {},
  }) {
    final userId = map['user_id']?.toString() ?? 'Usuario desconocido';
    final name = map['sendero_nick']?.toString().trim() ?? '';
    final sport = map['deporte']?.toString().trim();
    final photo = publicR2Url(map['foto_sendero']?.toString());
    final authorName = userNames[userId] ?? userId;
    final authorPhoto = publicR2Url(userPhotos[userId]);

    return ExploreTrail(
      id: (map['id'] as num?)?.toInt(),
      userId: userId,
      name: name.isEmpty ? 'Sendero sin nombre' : name,
      description: map['descripcion']?.toString() ?? '',
      difficulty: map['dificultad']?.toString() ?? 'Sin dificultad',
      sport: sport?.isNotEmpty == true ? sport! : 'Sin especificar',
      distanceKm: (map['distancia'] as num?)?.toDouble() ?? 0,
      elevation: 'Desnivel no disponible',
      author: authorName,
      authorPhotoUrl: authorPhoto,
      photoUrl: photo,
      gpxKey: map['gpx_key']?.toString(),
    );
  }

  factory ExploreTrail.fromDownloadedMetadata(Map<String, dynamic> metadata) {
    final name = metadata['name']?.toString().trim();
    final author = metadata['author']?.toString().trim();
    return ExploreTrail(
      id: (metadata['senderoId'] as num?)?.toInt(),
      userId: metadata['userId']?.toString(),
      name: name == null || name.isEmpty ? 'Sendero sin nombre' : name,
      description: metadata['description']?.toString() ?? '',
      difficulty: metadata['difficulty']?.toString() ?? 'Sin dificultad',
      sport: metadata['sport']?.toString() ?? 'Sin especificar',
      distanceKm: (metadata['distanceKm'] as num?)?.toDouble() ?? 0,
      elevation: metadata['elevation']?.toString() ?? 'Desnivel no disponible',
      author: author == null || author.isEmpty ? 'Sendero descargado' : author,
      authorPhotoUrl: publicR2Url(metadata['authorPhotoUrl']?.toString()),
      photoUrl: publicR2Url(metadata['photoUrl']?.toString()),
      gpxKey: metadata['downloadedSourceKey']?.toString(),
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
  final String? userId;
  final String name;
  final String description;
  final String difficulty;
  final String sport;
  final double distanceKm;
  final String elevation;
  final String author;
  final String? authorPhotoUrl;
  final String? photoUrl;
  final String? localPhotoPath;
  final String? gpxKey;

  String? get gpxUrl => publicR2Url(gpxKey);
}

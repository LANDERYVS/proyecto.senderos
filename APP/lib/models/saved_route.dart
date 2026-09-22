import 'dart:io';

class SavedRoute {
  const SavedRoute({required this.file, this.metadata});

  final File file;
  final Map<String, dynamic>? metadata;

  String get name =>
      metadata?['name'] as String? ??
      file.uri.pathSegments.last.replaceFirst(RegExp(r'\.gpx$'), '');

  String get description => metadata?['description'] as String? ?? '';

  String get difficulty => metadata?['difficulty'] as String? ?? 'Fácil';

  bool get isFavorite => metadata?['isFavorite'] as bool? ?? false;

  bool get isCreatedByUser => metadata?['createdByUser'] as bool? ?? true;

  bool get uploadedToR2 => metadata?['uploaded_to_r2'] as bool? ?? false;

  String? get r2GpxKey => metadata?['gpx_key'] as String?;

  List<String> get r2PhotoPaths =>
      (metadata?['r2_photo_paths'] as List<dynamic>?)?.cast<String>() ??
      const [];

  List<String> get photos =>
      (metadata?['photos'] as List<dynamic>?)?.cast<String>() ?? const [];
}

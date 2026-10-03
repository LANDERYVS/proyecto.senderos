import 'package:image_picker/image_picker.dart';

class RouteDetails {
  const RouteDetails({
    required this.name,
    required this.description,
    required this.sport,
    required this.difficulty,
    required this.photos,
  });

  final String name;
  final String description;
  final String sport;
  final String difficulty;
  final List<XFile> photos;
}

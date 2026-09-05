import 'package:image_picker/image_picker.dart';

class RouteDetails {
  const RouteDetails({
    required this.name,
    required this.description,
    required this.difficulty,
    required this.photos,
  });

  final String name;
  final String description;
  final String difficulty;
  final List<XFile> photos;
}

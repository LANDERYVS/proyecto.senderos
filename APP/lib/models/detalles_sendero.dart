import 'package:image_picker/image_picker.dart';

/*
 * Agrupa los datos que el usuario completa antes de guardar una ruta:
 * nombre, descripción, deporte, dificultad y fotos seleccionadas.
 * Así se pueden pasar juntos entre el formulario y el servicio que la guarda.
 */
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

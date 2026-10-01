import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:proyecto/models/saved_route.dart';
import 'package:proyecto/services/senderos_locales.dart';

void main() {
  test('edita los detalles y conserva el resto de la metadata', () async {
    final directory = await Directory.systemTemp.createTemp(
      'senderos_locales_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final routeFile = File('${directory.path}/sendero.gpx');
    final metadataFile = File('${directory.path}/sendero.json');
    final originalMetadata = {
      'name': 'Nombre anterior',
      'description': 'Descripción anterior',
      'difficulty': 'Fácil',
      'photos': ['sendero/foto.jpg'],
      'uploaded_to_r2': true,
    };
    await metadataFile.writeAsString(jsonEncode(originalMetadata));

    await SenderosLocalesService().updateRouteDetails(
      route: SavedRoute(file: routeFile, metadata: originalMetadata),
      name: 'Sendero editado',
      description: 'Descripción nueva',
      difficulty: 'Difícil',
    );

    final updated = jsonDecode(await metadataFile.readAsString()) as Map;
    expect(updated['name'], 'Sendero editado');
    expect(updated['description'], 'Descripción nueva');
    expect(updated['difficulty'], 'Difícil');
    expect(updated['photos'], originalMetadata['photos']);
    expect(updated['uploaded_to_r2'], isTrue);
  });

  test('reemplaza la foto principal y conserva las fotos restantes', () async {
    final directory = await Directory.systemTemp.createTemp(
      'senderos_photo_test_',
    );
    addTearDown(() async {
      if (await directory.exists()) await directory.delete(recursive: true);
    });

    final routeFile = File('${directory.path}/sendero.gpx');
    final metadataFile = File('${directory.path}/sendero.json');
    final selectedPhotoFile = File('${directory.path}/seleccionada.png');
    await selectedPhotoFile.writeAsBytes([1, 2, 3]);
    final originalMetadata = {
      'name': 'Sendero',
      'description': '',
      'difficulty': 'Fácil',
      'photos': ['sendero/foto_1.jpg', 'sendero/foto_2.jpg'],
    };
    await metadataFile.writeAsString(jsonEncode(originalMetadata));

    await SenderosLocalesService().updateRouteDetails(
      route: SavedRoute(file: routeFile, metadata: originalMetadata),
      name: 'Sendero',
      description: '',
      difficulty: 'Fácil',
      photo: XFile(selectedPhotoFile.path),
    );

    final updated = jsonDecode(await metadataFile.readAsString()) as Map;
    final photoPaths = updated['photos'] as List<dynamic>;
    expect(photoPaths, hasLength(2));
    expect(
      photoPaths.first,
      startsWith('sendero${Platform.pathSeparator}foto_'),
    );
    expect(photoPaths.first, endsWith('.png'));
    expect(photoPaths.last, 'sendero/foto_2.jpg');
    final savedPhotoPath = (photoPaths.first as String)
        .replaceAll('/', Platform.pathSeparator)
        .replaceAll('\\', Platform.pathSeparator);
    expect(
      await File(
        '${directory.path}${Platform.pathSeparator}$savedPhotoPath',
      ).readAsBytes(),
      [1, 2, 3],
    );
  });
}

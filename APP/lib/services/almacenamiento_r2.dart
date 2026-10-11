import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

// Error de carga que conserva el estado HTTP y los detalles devueltos por la función de R2.
class R2UploadException implements Exception {
  const R2UploadException({required this.statusCode, required this.details});

  final String statusCode;
  final String details;
}

/// Sube archivos a Cloudflare R2 mediante la Edge Function de Supabase.
class AlmacenamientoR2 {
  // Nombre de la Edge Function que recibe y almacena los archivos.
  static const _uploadFunction = 'r2-storage';

  // Sube un archivo y devuelve su clave dentro del almacenamiento remoto.
  Future<String> uploadFileToR2({
    required File file,
    required String folder,
    required String contentType,
    String? objectPrefix,
  }) async {
    // Evita invocar el servicio remoto si el archivo local no está disponible.
    if (!await file.exists()) {
      throw FileSystemException('El archivo no existe', file.path);
    }

    final fileName = file.uri.pathSegments.last;
    final remoteName = objectPrefix == null
        ? fileName
        : '$objectPrefix/$fileName';
    late final FunctionResponse response;
    try {
      // Envía el contenido binario y sus metadatos a la Edge Function.
      response = await Supabase.instance.client.functions.invoke(
        _uploadFunction,
        body: await file.readAsBytes(),
        headers: {
          'Content-Type': contentType,
          'x-file-name': remoteName,
          'x-folder': folder,
        },
      );
    } on FunctionException catch (error) {
      // Convierte el error de Supabase en una excepción con datos útiles para quien llama.
      throw R2UploadException(
        statusCode: error.status.toString(),
        details: (error.details ?? error.reasonPhrase ?? 'sin detalles')
            .toString(),
      );
    }

    final data = response.data;

    // Comprueba que la función confirme la carpeta y devuelva una clave dentro de ella.
    if (data is! Map ||
        data['folder'] != folder ||
        data['key'] is! String ||
        !(data['key'] as String).startsWith('$folder/')) {
      throw FormatException(
        'R2 no devolvió una respuesta válida para la carpeta $folder',
      );
    }

    // La clave identifica el archivo subido y permite referenciarlo después.
    return data['key'] as String;
  }

  // Configura la carga de un GPX con su carpeta y tipo de contenido específicos.
  Future<String> uploadGpxToR2({required File file, String? objectPrefix}) {
    return uploadFileToR2(
      file: file,
      folder: 'gpx',
      contentType: 'application/gpx+xml',
      objectPrefix: objectPrefix,
    );
  }
}

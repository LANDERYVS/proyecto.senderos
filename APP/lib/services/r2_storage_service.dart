import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente para subir archivos a Cloudflare R2 mediante una Edge Function.
/// Las claves de acceso de R2 permanecen únicamente en Supabase.
class R2StorageService {
  static const _uploadFunction = 'r2-storage';

  Future<String> uploadFileToR2({
    required File file,
    required String folder,
    required String contentType,
    String? objectPrefix,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('El archivo no existe', file.path);
    }

    final fileName = file.uri.pathSegments.last;
    final remoteName = objectPrefix == null
        ? fileName
        : '$objectPrefix/$fileName';
    late final FunctionResponse response;
    try {
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
      throw Exception(
        'Edge Function $_uploadFunction falló (${error.status}): '
        '${error.details ?? error.reasonPhrase ?? 'sin detalles'}',
      );
    }

    final data = response.data;

    if (data is! Map ||
        data['folder'] != folder ||
        data['key'] is! String ||
        !(data['key'] as String).startsWith('$folder/')) {
      throw FormatException(
        'R2 no devolvió una respuesta válida para la carpeta $folder',
      );
    }

    return data['key'] as String;
  }

  Future<String> uploadGpxToR2({required File file, String? objectPrefix}) {
    return uploadFileToR2(
      file: file,
      folder: 'gpx',
      contentType: 'application/gpx+xml',
      objectPrefix: objectPrefix,
    );
  }
}

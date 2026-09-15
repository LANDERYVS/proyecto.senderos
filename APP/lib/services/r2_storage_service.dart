import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Cliente para subir archivos a Cloudflare R2 mediante una Edge Function.
/// Las claves de acceso de R2 permanecen únicamente en Supabase.
class R2StorageService {
  static const _uploadFunction = 'r2-storage';

  Future<void> uploadGpxToR2({required File file}) async {
    if (!await file.exists()) {
      throw FileSystemException('El archivo no existe', file.path);
    }

    final fileName = file.uri.pathSegments.last;
    late final FunctionResponse response;
    try {
      response = await Supabase.instance.client.functions.invoke(
        _uploadFunction,
        body: await file.readAsBytes(),
        headers: {
          'Content-Type': 'application/gpx+xml',
          'x-file-name': fileName,
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
        data['folder'] != 'gpx' ||
        data['key'] is! String ||
        !(data['key'] as String).startsWith('gpx/')) {
      throw const FormatException('R2 no devolvió una respuesta válida');
    }
  }
}

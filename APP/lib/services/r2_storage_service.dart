import 'dart:convert';
import 'dart:io';

/// Cliente para subir archivos a Cloudflare R2 mediante una URL prefirmada.
///
/// La URL debe ser generada por una Edge Function de Supabase. Nunca coloques
/// las claves de acceso de R2 dentro de la aplicación Flutter.
class R2StorageService {
  final HttpClient _httpClient;

  R2StorageService({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  Future<void> uploadGpx({
    required File file,
    required Uri presignedUrl,
  }) async {
    await uploadFile(
      file: file,
      presignedUrl: presignedUrl,
      contentType: 'application/gpx+xml',
    );
  }

  Future<void> uploadFile({
    required File file,
    required Uri presignedUrl,
    required String contentType,
  }) async {
    if (!await file.exists()) {
      throw FileSystemException('El archivo no existe', file.path);
    }

    final request = await _httpClient.putUrl(presignedUrl);
    request.headers.contentType = ContentType.parse(contentType);
    request.headers.contentLength = await file.length();
    await request.addStream(file.openRead());

    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final responseBody = await utf8.decoder.bind(response).join();
      throw HttpException(
        'R2 rechazó la subida (${response.statusCode}): $responseBody',
        uri: presignedUrl,
      );
    }
  }

  void dispose() {
    _httpClient.close(force: true);
  }
}

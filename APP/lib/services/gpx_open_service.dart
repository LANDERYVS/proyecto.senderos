import 'dart:async';
import 'dart:io';

import 'package:app_links/app_links.dart';
import 'package:flutter/services.dart';

import 'gpx_import.dart';

class IncomingGpxPreview {
  const IncomingGpxPreview({required this.file, required this.route});

  final File file;
  final GpxRouteData route;
}

class GpxOpenService {
  static const _gpxChannel = MethodChannel('proyecto.senderos/gpx_files');

  final AppLinks _appLinks = AppLinks();
  final GpxImportService _gpxImportService = GpxImportService();
  final Set<String> _openingUris = {};
  StreamSubscription<Uri>? _linkSubscription;

  void start({
    required Future<void> Function(IncomingGpxPreview preview) onPreview,
    required void Function(Object error) onError,
  }) {
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) => unawaited(_openUri(uri, onPreview, onError)),
      onError: (Object error) => onError(error),
    );
    unawaited(_openInitialUri(onPreview, onError));
  }

  Future<void> _openInitialUri(
    Future<void> Function(IncomingGpxPreview preview) onPreview,
    void Function(Object error) onError,
  ) async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) await _openUri(uri, onPreview, onError);
    } on Exception catch (error) {
      onError(error);
    }
  }

  Future<void> _openUri(
    Uri uri,
    Future<void> Function(IncomingGpxPreview preview) onPreview,
    void Function(Object error) onError,
  ) async {
    if (!Platform.isAndroid ||
        (uri.scheme != 'content' && uri.scheme != 'file')) {
      return;
    }
    final uriString = uri.toString();
    if (!_openingUris.add(uriString)) return;

    try {
      final path = await _gpxChannel.invokeMethod<String>(
        'copyIncomingGpx',
        uriString,
      );
      if (path == null) return;
      final file = File(path);
      final route = await _gpxImportService.read(file);
      await onPreview(IncomingGpxPreview(file: file, route: route));
    } on Exception catch (error) {
      onError(error);
    } finally {
      _openingUris.remove(uriString);
    }
  }

  Future<void> dispose() async {
    await _linkSubscription?.cancel();
  }
}

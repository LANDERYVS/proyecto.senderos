import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/models/saved_route.dart';
import 'package:proyecto/services/guardado_local.dart';

void main() {
  group('RouteStorageService photo requirement', () {
    final service = RouteStorageService();
    final route = SavedRoute(file: File('sendero.gpx'));

    test('blocks publishing a route without photos', () async {
      await expectLater(
        service.publishRoute(route),
        throwsA(
          isA<RoutePublishException>().having(
            (error) => error.message,
            'message',
            contains('una foto'),
          ),
        ),
      );
    });

    test('blocks direct upload of a route without photos', () async {
      await expectLater(
        service.uploadToR2Only(route),
        throwsA(
          isA<RoutePublishException>().having(
            (error) => error.message,
            'message',
            contains('una foto'),
          ),
        ),
      );
    });
  });
}

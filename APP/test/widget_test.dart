import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/main.dart';

void main() {
  testWidgets('muestra el mapa y el botón de ubicación', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: HomePage(tileProvider: TestTileProvider())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Mapa en tiempo real'), findsOneWidget);
    expect(find.text('Actualizar ubicación'), findsOneWidget);
  });
}

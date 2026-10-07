import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/widgets/save_route_dialog.dart';

void main() {
  testWidgets('uses the imported route name as the initial name', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showSaveRouteDialog(
                  context,
                  duration: 'No disponible',
                  distanceKm: 2.4,
                  elevationGainMeters: 85,
                  initialName: 'Sendero importado',
                );
              },
              child: const Text('Abrir formulario'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();

    final nameField = tester.widget<TextField>(find.byType(TextField).first);
    expect(nameField.controller?.text, 'Sendero importado');
  });

  testWidgets('requires at least one photo before saving a route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () {
                showSaveRouteDialog(
                  context,
                  duration: '00:12:34',
                  distanceKm: 2.4,
                  elevationGainMeters: 85,
                );
              },
              child: const Text('Abrir formulario'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Abrir formulario'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Guardar'));
    await tester.pumpAndSettle();

    expect(
      find.text('Debes agregar al menos una foto para guardar el sendero.'),
      findsOneWidget,
    );
    expect(find.text('00:12:34'), findsOneWidget);
    expect(find.text('2.4 km'), findsOneWidget);
    expect(find.text('85 m'), findsOneWidget);
    expect(find.text('Deporte *'), findsOneWidget);
    expect(find.text('Senderismo'), findsOneWidget);
    expect(find.text('Fotos *'), findsOneWidget);
    expect(find.text('Guardar trayecto'), findsOneWidget);
  });
}

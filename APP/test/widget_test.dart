import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/main.dart';

void main() {
  testWidgets('muestra el login al abrir la app', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Iniciar sesión'), findsNWidgets(2));
    expect(
      find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Correo'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Contraseña'), findsOneWidget);
  });
}

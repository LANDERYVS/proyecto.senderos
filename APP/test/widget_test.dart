import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('muestra el login al abrir la app', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('Iniciar sesión'), findsNWidgets(2));
    expect(
      find.widgetWithText(ElevatedButton, 'Iniciar sesión'),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(TextField, 'Correo o nombre de usuario'),
      findsOneWidget,
    );
    expect(find.widgetWithText(TextField, 'Contraseña'), findsOneWidget);
  });

  testWidgets('abre la pantalla principal con una sesión guardada', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'isLoggedIn': true});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Explorar'), findsNWidgets(2));
    expect(
      find.widgetWithText(TextField, 'Correo o nombre de usuario'),
      findsNothing,
    );
  });

  testWidgets('abre el perfil desde la navegación inferior', (tester) async {
    SharedPreferences.setMockInitialValues({'isLoggedIn': true});
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Mi perfil'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.textContaining('Bloqueado'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Explorador'), 200);
    expect(find.textContaining('Bloqueado'), findsNWidgets(2));
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
  });

  testWidgets('permite iniciar sesión con el nombre de usuario', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'registeredEmail': 'senderista@gmail.com',
      'registeredUsername': 'senderista',
      'registeredPassword': '123456',
    });
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Correo o nombre de usuario'),
      'senderista',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Contraseña'),
      '123456',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Iniciar sesión'));
    await tester.pumpAndSettle();

    expect(find.text('Explorar'), findsNWidgets(2));
  });
}

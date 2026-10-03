import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/main.dart';
import 'package:proyecto/models/explore_trail.dart';
import 'package:proyecto/screen/detalle_sendero.dart';
import 'package:proyecto/widgets/default_user_avatar.dart';
import 'package:proyecto/widgets/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reconstruye la identidad de un sendero descargado', () {
    final trail = ExploreTrail.fromDownloadedMetadata({
      'senderoId': 42,
      'downloadedSourceKey': 'senderos/ruta.gpx',
      'name': 'Ruta local',
      'description': 'Una descripción',
      'difficulty': 'Moderado',
      'sport': 'Trail running',
      'distanceKm': 6.5,
      'photoUrl': 'senderos/ruta.jpg',
      'author': 'Senderista',
      'authorPhotoUrl': 'avatars/senderista.jpg',
    });

    expect(trail.id, 42);
    expect(trail.gpxKey, 'senderos/ruta.gpx');
    expect(trail.name, 'Ruta local');
    expect(trail.description, 'Una descripción');
    expect(trail.difficulty, 'Moderado');
    expect(trail.sport, 'Trail running');
    expect(trail.distanceKm, 6.5);
    expect(trail.photoUrl, contains('/senderos/ruta.jpg'));
    expect(trail.author, 'Senderista');
    expect(trail.authorPhotoUrl, contains('/avatars/senderista.jpg'));
  });

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

  testWidgets('muestra teléfono solo al crear una cuenta', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: LoginScreen(home: SizedBox.shrink())),
    );

    expect(find.text('Número de teléfono'), findsNothing);
    final createAccountButton = find.text('No tengo una cuenta, crear una');
    await tester.ensureVisible(createAccountButton);
    await tester.tap(createAccountButton);
    await tester.pumpAndSettle();

    final phoneField = find.widgetWithText(TextField, 'Número de teléfono *');
    expect(phoneField, findsOneWidget);
    expect(
      tester.widget<TextField>(phoneField).keyboardType,
      TextInputType.phone,
    );
    expect(find.text('Nombre de usuario *'), findsOneWidget);
    expect(find.text('Correo electrónico *'), findsOneWidget);
    expect(find.text('Contraseña *'), findsOneWidget);
    expect(find.text('Confirmar contraseña *'), findsOneWidget);
    expect(find.text('Foto de perfil'), findsOneWidget);
    expect(find.text('Foto de perfil *'), findsNothing);
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

  testWidgets('usa la imagen por defecto cuando no hay foto del usuario', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: DefaultUserAvatar())),
      ),
    );
    await tester.pumpAndSettle();

    final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
    expect(circle.backgroundImage, isA<AssetImage>());
    expect(
      (circle.backgroundImage as AssetImage).assetName,
      'assets/usuario.png',
    );
  });

  testWidgets(
    'normaliza la foto del usuario almacenada como clave de storage',
    (tester) async {
      const photoKey = 'avatars/test-user.png';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: DefaultUserAvatar(imageUrl: photoKey)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final circle = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(circle.backgroundImage, isA<NetworkImage>());
      expect(
        (circle.backgroundImage as NetworkImage).url,
        contains(
          'pub-a4c1361bdcbd4ab38809613ea21575c2.r2.dev/avatars/test-user.png',
        ),
      );
    },
  );

  testWidgets(
    'muestra la foto y el nombre del autor en el detalle del sendero',
    (tester) async {
      final trail = ExploreTrail(
        name: 'Sendero de prueba',
        description: 'Descripción corta',
        difficulty: 'Moderado',
        distanceKm: 4.5,
        elevation: '180 m',
        author: 'Senderista',
        authorPhotoUrl: 'https://example.com/avatar.png',
        photoUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(home: DetalleSenderoScreen(trail: trail)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Publicado por: Senderista'), findsOneWidget);
      expect(find.byType(CircleAvatar), findsOneWidget);
    },
  );

  testWidgets('muestra el botón de seguir sendero en la vista de detalle', (
    tester,
  ) async {
    final trail = ExploreTrail(
      name: 'Sendero de prueba',
      description: 'Descripción corta',
      difficulty: 'Moderado',
      distanceKm: 4.5,
      elevation: '180 m',
      author: 'Senderista',
      photoUrl: null,
    );

    await tester.pumpWidget(
      MaterialApp(home: DetalleSenderoScreen(trail: trail)),
    );
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Seguir sendero'), findsOneWidget);
  });
}

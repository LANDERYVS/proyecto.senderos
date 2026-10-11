import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/widgets/content_state_view.dart';
import 'package:proyecto/widgets/dialogo_salir_ruta.dart';
import 'package:proyecto/widgets/mapa_trazado_sendero.dart';
import 'package:proyecto/widgets/metricas_senderos.dart';
import 'package:proyecto/widgets/no_transition_page_route.dart';

void main() {
  test('NoTransitionPageRoute no anima al entrar ni al salir', () {
    final route = NoTransitionPageRoute<void>(
      builder: (_) => const SizedBox.shrink(),
    );

    expect(route.transitionDuration, Duration.zero);
    expect(route.reverseTransitionDuration, Duration.zero);
  });

  testWidgets('ContentStateView muestra un indicador de carga', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ContentStateView(isLoading: true)),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('ContentStateView muestra un mensaje vacío', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: ContentStateView(message: 'No hay resultados')),
      ),
    );

    expect(find.text('No hay resultados'), findsOneWidget);
  });

  testWidgets('ContentStateView permite reintentar', (tester) async {
    var retried = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ContentStateView(
            message: 'No se pudieron cargar los datos',
            onRetry: () => retried = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Reintentar'));

    expect(retried, isTrue);
  });

  testWidgets('GrabarMetricsPanel distingue grabando y pausado', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrabarMetricsPanel(
            duration: '00:01:00',
            distanceKm: 1.2,
            elevationGainMeters: 12,
            isRecording: true,
            status: 'Grabando: 1.20 km',
            onTogglePause: () {},
            onStop: () {},
          ),
        ),
      ),
    );

    expect(find.text('GRABANDO'), findsOneWidget);
    expect(find.text('TIEMPO'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrabarMetricsPanel(
            duration: '00:01:00',
            distanceKm: 1.2,
            elevationGainMeters: 12,
            isRecording: true,
            isPaused: true,
            status: 'Grabación pausada',
            onTogglePause: () {},
            onStop: () {},
          ),
        ),
      ),
    );

    expect(find.text('PAUSADO'), findsOneWidget);
    expect(find.text('GRABANDO'), findsNothing);
    expect(find.text('Reanudar'), findsOneWidget);
    expect(find.text('Detener'), findsOneWidget);
  });

  testWidgets('ConfirmExitRecordingDialog prioriza seguir grabando', (
    tester,
  ) async {
    var continued = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConfirmExitRecordingDialog(
            message: 'La grabación sigue en curso.',
            summary: '00:12:34 · 2.4 km · +85 m',
            onContinue: () => continued = true,
            onExit: () {},
          ),
        ),
      ),
    );

    expect(find.text('¿Salir sin guardar?'), findsOneWidget);
    expect(find.text('00:12:34 · 2.4 km · +85 m'), findsOneWidget);
    expect(find.text('Salir y descartar'), findsOneWidget);
    expect(
      tester.getRect(find.text('Salir y descartar')).center.dy,
      tester.getRect(find.text('Seguir grabando')).center.dy,
    );
    await tester.tap(find.text('Seguir grabando'));

    expect(continued, isTrue);
  });

  testWidgets('RoutePolylineMap muestra un estado si la ruta no tiene puntos', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: RoutePolylineMap(points: [])),
      ),
    );

    expect(find.text('El trayecto no está disponible'), findsOneWidget);
  });
}

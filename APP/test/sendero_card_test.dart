import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/models/modelo_sendero.dart';
import 'package:proyecto/widgets/sendero_card.dart';

void main() {
  testWidgets('SenderoCard muestra compartir en lugar de favorito', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SenderoCard(
            trail: ExploreTrail(
              name: 'Sendero de prueba',
              description: '',
              difficulty: 'Fácil',
              distanceKm: 2.5,
              elevation: '100 m',
              author: 'Autora',
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Compartir sendero'), findsOneWidget);
    expect(find.byIcon(Icons.share_outlined), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border), findsNothing);
  });
}

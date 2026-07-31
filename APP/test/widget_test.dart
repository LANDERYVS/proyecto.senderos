import 'package:flutter_test/flutter_test.dart';
import 'package:real_time_map_app/main.dart';

void main() {
  testWidgets('muestra el mapa y el botón de ubicación', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Mapa en tiempo real'), findsOneWidget);
    expect(find.text('Actualizar ubicación'), findsOneWidget);
  });
}

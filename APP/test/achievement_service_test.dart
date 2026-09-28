import 'package:fifty_achievement_engine/fifty_achievement_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/services/achievement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'desbloquea el primer sendero una sola vez y persiste el progreso',
    () async {
      final service = AchievementService(
        supabaseClient: SupabaseClient(
          'https://example.supabase.co',
          'test-key',
        ),
      );
      await service.initialize();

      expect(service.isFirstTrailUnlocked, isFalse);
      expect(await service.recordFirstTrail(), isTrue);
      expect(await service.recordFirstTrail(), isFalse);

      final restoredService = AchievementService(
        supabaseClient: SupabaseClient(
          'https://example.supabase.co',
          'test-key',
        ),
      );
      await restoredService.initialize();
      expect(restoredService.isFirstTrailUnlocked, isTrue);
    },
  );

  test('crea logros desde filas de la tabla logros', () {
    final achievements = AchievementService.achievementDefinitionsFromRows([
      {
        'id': 'first_trail',
        'name': 'Primer sendero',
        'description': 'Crea tu primer sendero',
        'event': 'first_trail_created',
        'points': 10,
        'category': 'Senderismo',
      },
      {
        'id': 'explorer',
        'nombre': 'Explorador',
        'descripcion': 'Descubre 5 senderos',
        'event_name': 'trail_explored',
        'puntos': 25,
        'categoria': 'Exploración',
      },
    ]);

    expect(achievements, hasLength(2));
    expect(achievements.first.id, 'first_trail');
    expect(achievements.first.condition.type, 'event');
    expect(achievements.last.name, 'Explorador');
    expect(achievements.last.points, 25);
  });

  test(
    'detecta un logro desbloqueado cuando se dispara un evento de conteo',
    () async {
      final service = AchievementService(
        supabaseClient: SupabaseClient(
          'https://example.supabase.co',
          'test-key',
        ),
      );

      service.controller.addAchievement(
        Achievement<void>(
          id: 'route_lover',
          name: 'Amante de rutas',
          description: 'Guarda 5 rutas favoritas',
          condition: CountCondition('favorite_saved', target: 5),
          points: 35,
        ),
      );

      await service.initialize();

      for (var i = 0; i < 4; i++) {
        final unlocked = await service.recordEvent('favorite_saved');
        expect(unlocked, isNull);
      }

      final unlocked = await service.recordEvent('favorite_saved');
      expect(unlocked, isNotNull);
      expect(unlocked!.id, 'route_lover');
    },
  );
}

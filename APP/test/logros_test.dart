import 'package:fifty_achievement_engine/fifty_achievement_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/models/logro.dart';

void main() {
  test('maps a database requirement to the engine stat', () {
    final achievement = Logro.fromMap({
      'id': 12,
      'nombre': 'Primer sendero',
      'descripcion': 'Publica un sendero',
      'requisito': 'senderos_publicados',
      'valor_logro': 1,
    });

    expect(achievement.metricKey, 'senderos_publicados');
    expect(achievement.target, 1);
  });

  test('maps social achievement requirements to engine stats', () {
    final friendAchievement = Logro.fromMap({
      'id': 14,
      'nombre': 'Amiguero',
      'descripcion': 'Consigue 5 amigos',
      'requisito': 'amigos',
      'valor_logro': 5,
    });
    final spectatorAchievement = Logro.fromMap({
      'id': 15,
      'nombre': 'Espectador',
      'descripcion': 'Sé espectador de alguien',
      'requisito': 'espectador',
      'valor_logro': 1,
    });
    final allAchievements = Logro.fromMap({
      'id': 16,
      'nombre': 'Coleccionista',
      'descripcion': 'Consigue todos los demás logros',
      'requisito': 'todos_los_logros',
      'valor_logro': 1,
    }, totalAchievements: 7);

    expect(friendAchievement.metricKey, 'amigos');
    expect(spectatorAchievement.metricKey, 'espectador');
    expect(allAchievements.metricKey, 'todos_los_logros');
    expect(allAchievements.target, 6);
  });

  test('engine tracks achievement progress and unlocks at its threshold', () {
    final achievement = Logro.fromMap({
      'id': 13,
      'nombre': 'Kilómetros recorridos',
      'descripcion': 'Publica rutas que sumen 25 km',
      'requisito': 'distancia_km',
      'valor_logro': 25,
    });
    final controller = AchievementController<Logro>(
      achievements: [
        Achievement<Logro>(
          id: achievement.id.toString(),
          name: achievement.name,
          description: achievement.description,
          condition: ThresholdCondition(
            achievement.metricKey!,
            target: achievement.target,
          ),
          data: achievement,
        ),
      ],
    );
    addTearDown(controller.dispose);

    controller.updateStat('distancia_km', 12.5);
    expect(controller.getProgress('13'), 0.5);
    expect(controller.isUnlocked('13'), isFalse);

    controller.updateStat('distancia_km', 25);
    expect(controller.getProgress('13'), 1);
    expect(controller.isUnlocked('13'), isTrue);
  });
}

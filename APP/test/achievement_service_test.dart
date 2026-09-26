import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto/services/achievement_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'desbloquea el primer sendero una sola vez y persiste el progreso',
    () async {
      final service = AchievementService();
      await service.initialize();

      expect(service.isFirstTrailUnlocked, isFalse);
      expect(await service.recordFirstTrail(), isTrue);
      expect(await service.recordFirstTrail(), isFalse);

      final restoredService = AchievementService();
      await restoredService.initialize();
      expect(restoredService.isFirstTrailUnlocked, isTrue);
    },
  );
}

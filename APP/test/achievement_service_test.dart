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
}

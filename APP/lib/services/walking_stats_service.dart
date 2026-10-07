import 'package:supabase_flutter/supabase_flutter.dart';

class WalkingStatsException implements Exception {
  const WalkingStatsException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WalkingStatsService {
  WalkingStatsService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<void> recordCompletedWalk({
    required double distanceKm,
  }) async {
    if (!distanceKm.isFinite || distanceKm < 0) {
      throw const WalkingStatsException(
        'La distancia de la caminata no es válida.',
      );
    }
    if (distanceKm == 0) return;

    try {
      await _client.rpc(
        'record_walking_distance',
        params: {'p_distance_km': distanceKm},
      );
    } on Exception catch (error) {
      throw WalkingStatsException(
        'No se pudieron registrar los kilómetros caminados. '
        'Comprueba tu conexión e inténtalo de nuevo. ($error)',
      );
    }
  }
}

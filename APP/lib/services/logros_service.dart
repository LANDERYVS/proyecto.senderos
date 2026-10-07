import 'package:achievement_view/achievement_view.dart';
import 'package:fifty_achievement_engine/fifty_achievement_engine.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/logro.dart';

class LogrosSession {
  const LogrosSession({
    required this.controller,
    required this.achievements,
    required this.newlyUnlocked,
    required this.publishedTrails,
    required this.distanceKm,
    required this.waypoints,
  });

  final AchievementController<Logro> controller;
  final List<Logro> achievements;
  final List<Logro> newlyUnlocked;
  final int publishedTrails;
  final double distanceKm;
  final int waypoints;
}

class LogrosService {
  LogrosService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<LogrosSession> loadAndSync() async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Inicia sesión para ver tus logros.');

    final achievementRows = await _client
        .from('logros')
        .select('id, nombre, descripcion, requisito, valor_logro')
        .order('id');
    final achievements = (achievementRows as List)
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => Logro.fromMap(
            row,
            totalAchievements: (achievementRows as List).length,
          ),
        )
        .where((achievement) => achievement.metricKey != null)
        .toList();

    final earnedRows = await _client
        .from('user_logros')
        .select('logro_id')
        .eq('user_id', user.id);
    final earnedIds = (earnedRows as List)
        .whereType<Map<String, dynamic>>()
        .map((row) => (row['logro_id'] as num).toInt())
        .toSet();

    final friendshipRows = await _client
        .from('amistades')
        .select('id')
        .or('users_id.eq.${user.id},target_id.eq.${user.id}');
    final friendCount = (friendshipRows as List).length;

    final spectatorRows = await _client
        .from('relaciones_espectadores')
        .select('amistad')
        .eq('espectador_id', user.id)
        .eq('enabled', true);
    final spectatorFriendshipIds = (spectatorRows as List)
        .whereType<Map<String, dynamic>>()
        .map((row) => row['amistad'])
        .toSet();

    final trailRows = await _client
        .from('senderos')
        .select('id')
        .eq('user_id', user.id);
    final userStats = await _client
        .from('usuarios')
        .select('kilometros_caminados')
        .eq('id', user.id)
        .single();
    final trails = (trailRows as List).whereType<Map<String, dynamic>>();
    final trailIds = <int>[];
    for (final trail in trails) {
      final id = (trail['id'] as num?)?.toInt();
      if (id != null) trailIds.add(id);
    }
    final distanceKm =
        (userStats['kilometros_caminados'] as num?)?.toDouble() ?? 0;

    var waypointCount = 0;
    if (trailIds.isNotEmpty) {
      final waypointRows = await _client
          .from('waypoint')
          .select('id')
          .inFilter('sendero_id', trailIds);
      waypointCount = (waypointRows as List).length;
    }

    final controller = AchievementController<Logro>(
      achievements: [
        for (final achievement in achievements)
          Achievement<Logro>(
            id: achievement.id.toString(),
            name: achievement.name,
            description: achievement.description,
            condition: ThresholdCondition(
              achievement.metricKey!,
              target: achievement.target,
            ),
            icon: Icons.emoji_events_outlined,
            category: achievement.metricKey,
            points: 0,
            data: achievement,
          ),
      ],
    );

    for (final id in earnedIds) {
      controller.forceUnlock(id.toString());
    }
    controller
      ..updateStat('senderos_publicados', trailIds.length)
      ..updateStat('distancia_km', distanceKm)
      ..updateStat('waypoints', waypointCount)
      ..updateStat('amigos', friendCount)
      ..updateStat('espectador', spectatorFriendshipIds.length)
      ..updateStat('todos_los_logros', earnedIds.length);

    final claimedRows = await _client.rpc('claim_eligible_achievements');
    final newlyUnlockedIds = (claimedRows as List)
        .whereType<Map<String, dynamic>>()
        .map((row) => (row['logro_id'] as num).toInt())
        .toSet();
    for (final id in newlyUnlockedIds) {
      controller.forceUnlock(id.toString());
    }

    final achievementsById = {
      for (final achievement in achievements) achievement.id: achievement,
    };
    return LogrosSession(
      controller: controller,
      achievements: achievements,
      newlyUnlocked: [
        ...newlyUnlockedIds
            .map((id) => achievementsById[id])
            .whereType<Logro>(),
      ],
      publishedTrails: trailIds.length,
      distanceKm: distanceKm,
      waypoints: waypointCount,
    );
  }
}

Future<void> showLogroNotifications(
  BuildContext context,
  List<Logro> achievements,
) async {
  for (var index = 0; index < achievements.length; index++) {
    if (!context.mounted) return;
    final achievement = achievements[index];
    AchievementView(
      title: achievement.name,
      subTitle: 'Logro desbloqueado',
      icon: const Icon(Icons.emoji_events_rounded, color: Colors.white),
      color: const Color(0xff4f683c),
      duration: const Duration(seconds: 3),
    ).show(context);

    if (index < achievements.length - 1) {
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }
}

import 'dart:convert';

import 'package:fifty_achievement_engine/fifty_achievement_engine.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AchievementService {
  AchievementService({
    SharedPreferences? preferences,
    SupabaseClient? supabaseClient,
  }) : _preferences = preferences,
       _supabaseClient = supabaseClient;

  static final AchievementService instance = AchievementService();
  static const _progressKey = 'achievement_progress_v1';
  static const _tableName = 'progreso_logros';
  static const firstTrailId = 'first_trail';

  final AchievementController<void> controller = AchievementController<void>(
    achievements: [
      Achievement<void>(
        id: firstTrailId,
        name: 'Creaste tu primer sendero',
        description: 'Graba y guarda tu primer sendero.',
        condition: EventCondition('first_trail_created'),
        rarity: AchievementRarity.common,
        points: 10,
        category: 'Senderismo',
        icon: Icons.emoji_events_outlined,
      ),
    ],
  );

  SharedPreferences? _preferences;
  final SupabaseClient? _supabaseClient;
  Future<void>? _initialization;
  String? _loadedUserId;
  bool _hasLoadedIdentity = false;
  int _loadGeneration = 0;

  SupabaseClient get _client => _supabaseClient ?? Supabase.instance.client;

  Achievement<void> get firstTrailAchievement =>
      controller.getAchievement(firstTrailId)!;

  bool get isFirstTrailUnlocked => controller.isUnlocked(firstTrailId);

  Future<void> initialize() {
    final userId = _client.auth.currentUser?.id;
    if (_hasLoadedIdentity && _loadedUserId == userId) {
      return _initialization!;
    }

    _hasLoadedIdentity = true;
    _loadedUserId = userId;
    final generation = ++_loadGeneration;
    controller.reset();
    return _initialization = _loadProgress(userId, generation);
  }

  Future<bool> recordFirstTrail() async {
    await initialize();
    if (isFirstTrailUnlocked) {
      await _saveProgress(_loadedUserId);
      return false;
    }

    controller.trackEvent('first_trail_created');
    await _saveProgress(_loadedUserId);
    return isFirstTrailUnlocked;
  }

  Future<void> _loadProgress(String? userId, int generation) async {
    _preferences ??= await SharedPreferences.getInstance();
    final localKey = _localProgressKey(userId);
    final localProgress = _decodeProgress(_preferences!.getString(localKey));
    Map<String, dynamic>? remoteProgress;
    var remoteReadSucceeded = userId == null;

    if (userId != null) {
      try {
        final row = await _client
            .from(_tableName)
            .select('progress')
            .eq('user_id', userId)
            .maybeSingle();
        remoteProgress = _asStringMap(row?['progress']);
        remoteReadSucceeded = true;
      } on Exception catch (error) {
        debugPrint('No se pudo cargar el progreso de logros: $error');
      }
    }

    if (generation != _loadGeneration) return;
    final progress = _mergeProgress(localProgress, remoteProgress);
    if (progress == null) return;

    controller.importProgress(progress);
    await _preferences!.setString(localKey, jsonEncode(progress));
    if (userId != null && remoteReadSucceeded) {
      await _syncProgress(userId, progress);
    }
  }

  Future<void> _saveProgress(String? userId) async {
    _preferences ??= await SharedPreferences.getInstance();
    final progress = controller.exportProgress();
    await _preferences!.setString(
      _localProgressKey(userId),
      jsonEncode(progress),
    );
    if (userId != null) await _syncProgress(userId, progress);
  }

  Future<void> _syncProgress(
    String userId,
    Map<String, dynamic> progress,
  ) async {
    try {
      await _client.from(_tableName).upsert({
        'user_id': userId,
        'progress': progress,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id');
    } on Exception catch (error) {
      debugPrint(
        'El progreso de logros queda pendiente de sincronización: $error',
      );
    }
  }

  String _localProgressKey(String? userId) =>
      '${_progressKey}_${userId ?? 'guest'}';

  Map<String, dynamic>? _decodeProgress(String? encoded) {
    if (encoded == null) return null;
    try {
      return _asStringMap(jsonDecode(encoded));
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic>? _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  Map<String, dynamic>? _mergeProgress(
    Map<String, dynamic>? local,
    Map<String, dynamic>? remote,
  ) {
    if (local == null) return remote;
    if (remote == null) return local;

    final merged = Map<String, dynamic>.from(remote);
    merged['unlocked'] = _mergeStringLists(
      local['unlocked'],
      remote['unlocked'],
    );
    merged['claimed'] = _mergeStringLists(local['claimed'], remote['claimed']);

    final localUnlockTimes = _asStringMap(local['unlockTimes']) ?? {};
    final remoteUnlockTimes = _asStringMap(remote['unlockTimes']) ?? {};
    merged['unlockTimes'] = {...localUnlockTimes, ...remoteUnlockTimes};

    final localContext = _asStringMap(local['context']) ?? {};
    final remoteContext = _asStringMap(remote['context']) ?? {};
    merged['context'] = {
      ...remoteContext,
      'eventCounts': _mergeMaxValues(
        localContext['eventCounts'],
        remoteContext['eventCounts'],
      ),
      'stats': _mergeMaxValues(localContext['stats'], remoteContext['stats']),
      'eventSequence': _longerList(
        localContext['eventSequence'],
        remoteContext['eventSequence'],
      ),
      'customData': {
        ...?_asStringMap(localContext['customData']),
        ...?_asStringMap(remoteContext['customData']),
      },
    };
    final localSessionStart = localContext['sessionStart'] as String?;
    final remoteSessionStart = remoteContext['sessionStart'] as String?;
    if (localSessionStart != null || remoteSessionStart != null) {
      merged['context']['sessionStart'] = _earliestDate(
        localSessionStart,
        remoteSessionStart,
      );
    }
    return merged;
  }

  List<String> _mergeStringLists(Object? first, Object? second) => {
    ...((first as List<dynamic>?)?.whereType<String>() ?? const <String>[]),
    ...((second as List<dynamic>?)?.whereType<String>() ?? const <String>[]),
  }.toList();

  Map<String, num> _mergeMaxValues(Object? first, Object? second) {
    final firstMap = _asStringMap(first) ?? {};
    final secondMap = _asStringMap(second) ?? {};
    final merged = <String, num>{};
    for (final key in {...firstMap.keys, ...secondMap.keys}) {
      final firstValue = firstMap[key];
      final secondValue = secondMap[key];
      if (firstValue is num && secondValue is num) {
        merged[key] = firstValue >= secondValue ? firstValue : secondValue;
      } else if (firstValue is num) {
        merged[key] = firstValue;
      } else if (secondValue is num) {
        merged[key] = secondValue;
      }
    }
    return merged;
  }

  List<dynamic> _longerList(Object? first, Object? second) {
    final firstList = first as List<dynamic>? ?? const [];
    final secondList = second as List<dynamic>? ?? const [];
    return firstList.length >= secondList.length ? firstList : secondList;
  }

  String _earliestDate(String? first, String? second) {
    if (first == null) return second!;
    if (second == null) return first;
    final firstDate = DateTime.tryParse(first);
    final secondDate = DateTime.tryParse(second);
    if (firstDate == null) return second;
    if (secondDate == null) return first;
    return firstDate.isBefore(secondDate) ? first : second;
  }
}

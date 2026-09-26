import 'dart:convert';

import 'package:fifty_achievement_engine/fifty_achievement_engine.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AchievementService {
  AchievementService({SharedPreferences? preferences})
    : _preferences = preferences;

  static final AchievementService instance = AchievementService();
  static const _progressKey = 'achievement_progress_v1';
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
  Future<void>? _initialization;

  Achievement<void> get firstTrailAchievement =>
      controller.getAchievement(firstTrailId)!;

  bool get isFirstTrailUnlocked => controller.isUnlocked(firstTrailId);

  Future<void> initialize() => _initialization ??= _loadProgress();

  Future<bool> recordFirstTrail() async {
    await initialize();
    if (isFirstTrailUnlocked) return false;

    controller.trackEvent('first_trail_created');
    await _saveProgress();
    return isFirstTrailUnlocked;
  }

  Future<void> _loadProgress() async {
    _preferences ??= await SharedPreferences.getInstance();
    final savedProgress = _preferences!.getString(_progressKey);
    if (savedProgress == null) return;

    final progress = jsonDecode(savedProgress) as Map<String, dynamic>;
    controller.importProgress(progress);
  }

  Future<void> _saveProgress() async {
    await _preferences!.setString(
      _progressKey,
      jsonEncode(controller.exportProgress()),
    );
  }
}

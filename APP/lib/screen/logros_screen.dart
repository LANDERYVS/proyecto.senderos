import 'package:flutter/material.dart';

import '../models/logro.dart';
import '../services/logros_service.dart';

class LogrosScreen extends StatefulWidget {
  const LogrosScreen({super.key});

  @override
  State<LogrosScreen> createState() => _LogrosScreenState();
}

class _LogrosScreenState extends State<LogrosScreen> {
  final LogrosService _logrosService = LogrosService();
  LogrosSession? _session;
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAchievements();
  }

  @override
  void dispose() {
    _session?.controller.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    LogrosSession? nextSession;
    try {
      nextSession = await _logrosService.loadAndSync();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar los logros: $error';
        _isLoading = false;
      });
      return;
    }

    if (!mounted) {
      nextSession.controller.dispose();
      return;
    }

    final previousSession = _session;
    setState(() {
      _session = nextSession;
      _isLoading = false;
    });
    previousSession?.controller.dispose();
    await showLogroNotifications(context, nextSession.newlyUnlocked);
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return Scaffold(
      appBar: AppBar(title: const Text('Mis logros')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _loadAchievements,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            )
          : session == null
          ? const SizedBox.shrink()
          : RefreshIndicator(
              onRefresh: _loadAchievements,
              child: AnimatedBuilder(
                animation: session.controller,
                builder: (context, _) => _buildAchievementList(session),
              ),
            ),
    );
  }

  Widget _buildAchievementList(LogrosSession session) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = session.controller;
    final unlockedCount = controller.unlockedIds.length;
    final totalCount = session.achievements.length;
    final completion = totalCount == 0 ? 0.0 : unlockedCount / totalCount;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$unlockedCount de $totalCount logros',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                '${session.publishedTrails} senderos · '
                '${session.distanceKm.toStringAsFixed(1)} km · '
                '${session.waypoints} waypoints',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: completion),
            ],
          ),
        ),
        if (session.achievements.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 36),
            child: Text(
              'Todavía no hay logros configurados.',
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final achievement in session.achievements)
            _AchievementProgressTile(
              achievement: achievement,
              progress: controller.getProgress(achievement.id.toString()),
              unlocked: controller.isUnlocked(achievement.id.toString()),
            ),
      ],
    );
  }
}

class _AchievementProgressTile extends StatelessWidget {
  const _AchievementProgressTile({
    required this.achievement,
    required this.progress,
    required this.unlocked,
  });

  final Logro achievement;
  final double progress;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: unlocked
                  ? colorScheme.primaryContainer
                  : colorScheme.surfaceContainerHighest,
              child: Icon(
                unlocked ? Icons.emoji_events : Icons.lock_outline,
                color: unlocked
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    achievement.name,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (achievement.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      achievement.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('${(progress * 100).round()}%'),
          ],
        ),
      ),
    );
  }
}

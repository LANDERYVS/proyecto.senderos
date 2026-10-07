import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/explore_trail.dart';
import '../widgets/default_user_avatar.dart';
import '../widgets/login_styles.dart';

class PublicProfilePage extends StatefulWidget {
  const PublicProfilePage({
    super.key,
    required this.userId,
    required this.initialName,
    required this.initialEmail,
    required this.isPremium,
    this.initialPhotoUrl,
  });

  final String userId;
  final String initialName;
  final String initialEmail;
  final bool isPremium;
  final String? initialPhotoUrl;

  @override
  State<PublicProfilePage> createState() => _PublicProfilePageState();
}

class _PublicProfilePageState extends State<PublicProfilePage> {
  bool _isLoadingStats = true;
  String? _statsError;
  int _publishedTrails = 0;
  double _distanceKm = 0;
  int _unlockedAchievements = 0;

  String? get _photoUrl => ExploreTrail.publicR2Url(widget.initialPhotoUrl);

  @override
  void initState() {
    super.initState();
    _loadActivityStats();
  }

  Future<void> _loadActivityStats() async {
    try {
      final client = Supabase.instance.client;
      final trailRows = await client
          .from('senderos')
          .select('id')
          .eq('user_id', widget.userId);
      final userStats = await client
          .from('usuarios')
          .select('kilometros_caminados')
          .eq('id', widget.userId)
          .single();
      final achievementRows = await client
          .from('user_logros')
          .select('logro_id')
          .eq('user_id', widget.userId);

      final distance =
          (userStats['kilometros_caminados'] as num?)?.toDouble() ?? 0;

      if (!mounted) return;
      setState(() {
        _publishedTrails = trailRows.length;
        _distanceKm = distance;
        _unlockedAchievements = achievementRows.length;
        _isLoadingStats = false;
      });
    } on Exception catch (error) {
      debugPrint(
        'No se pudieron cargar las estadísticas del perfil '
        '${widget.userId}: $error',
      );
      if (!mounted) return;
      setState(() {
        _statsError = 'No se pudieron cargar las estadísticas.';
        _isLoadingStats = false;
      });
    }
  }

  Widget _buildProfileHeader(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = colors.brightness == Brightness.dark;
    final headerForeground = isDark ? colors.onSurface : Colors.white;
    final headerGradient = isDark
        ? [colors.surfaceContainerHighest, colors.surfaceContainer]
        : [LoginStyles.deepGreen, LoginStyles.forestGreen];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: headerGradient,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: headerGradient.first.withAlpha(isDark ? 70 : 35),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: LoginStyles.accentGold,
                  shape: BoxShape.circle,
                ),
                child: DefaultUserAvatar(radius: 48, imageUrl: _photoUrl),
              ),
              const SizedBox(height: 16),
              Text(
                widget.initialName,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: headerForeground,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (widget.isPremium) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: LoginStyles.accentGold.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: LoginStyles.accentGold.withAlpha(150),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.workspace_premium_rounded,
                        size: 16,
                        color: LoginStyles.accentGold,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'THOPO PREMIUM',
                        style: TextStyle(
                          color: headerForeground,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  'Senderista THOPO',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: headerForeground.withAlpha(210),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildActivityStats(BuildContext context) {
    if (_isLoadingStats) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_statsError != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Text(
          _statsError!,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }

    return Row(
      children: [
        _ProfileStatCard(
          icon: Icons.route_outlined,
          value: '$_publishedTrails',
          label: 'Senderos',
        ),
        const SizedBox(width: 10),
        _ProfileStatCard(
          icon: Icons.terrain_outlined,
          value: _distanceKm.toStringAsFixed(1),
          label: 'Kilómetros',
        ),
        const SizedBox(width: 10),
        _ProfileStatCard(
          icon: Icons.emoji_events_outlined,
          value: '$_unlockedAchievements',
          label: 'Logros',
        ),
      ],
    );
  }

  Widget _buildProfileDetails(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
          child: Text(
            'Mi cuenta',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        if (widget.initialEmail.isNotEmpty)
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.outlineVariant.withAlpha(120)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 5,
              ),
              leading: CircleAvatar(
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.email_outlined,
                  color: colors.onPrimaryContainer,
                ),
              ),
              title: const Text(
                'Correo electrónico',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(widget.initialEmail),
            ),
          ),
        if (!_isLoadingStats && _statsError == null) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            color: colors.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(color: colors.outlineVariant.withAlpha(120)),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 5,
              ),
              leading: CircleAvatar(
                backgroundColor: colors.secondaryContainer,
                child: Icon(
                  Icons.emoji_events_outlined,
                  color: colors.onSecondaryContainer,
                ),
              ),
              title: const Text(
                'Logros',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('$_unlockedAchievements logros desbloqueados'),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          _buildProfileHeader(context),
          _buildActivityStats(context),
          _buildProfileDetails(context),
        ],
      ),
    );
  }
}

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        decoration: BoxDecoration(
          color: colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: colors.outlineVariant.withAlpha(120)),
        ),
        child: Column(
          children: [
            Icon(icon, color: colors.primary, size: 21),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

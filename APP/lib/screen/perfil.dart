import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'configuracion.dart';
import 'grabar.dart';
import 'inicio.dart';
import '../widgets/barra_navegacion.dart';

class _Achievement {
  const _Achievement({
    required this.title,
    required this.description,
    required this.requirement,
    required this.icon,
  });

  final String title;
  final String description;
  final String requirement;
  final IconData icon;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  String? _error;

  static const _achievements = [
    _Achievement(
      title: 'Primer sendero',
      description: 'Completa tu primer trayecto',
      requirement: 'Completa un trayecto para desbloquearlo',
      icon: Icons.emoji_events,
    ),
    _Achievement(
      title: 'Explorador',
      description: 'Descubre nuevos lugares',
      requirement: 'Descubre 5 lugares para desbloquearlo',
      icon: Icons.explore,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No hay una sesión iniciada';
      });
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('usuarios')
          .select('name, email, user_photo, premium')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = error.message;
      });
    }
  }

  String get _name {
    final profileName = _profile?['name']?.toString().trim();
    if (profileName?.isNotEmpty == true) return profileName!;

    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    final metadataName = (metadata?['name'] ?? metadata?['username'])
        ?.toString()
        .trim();
    return metadataName?.isNotEmpty == true ? metadataName! : 'Usuario';
  }

  String get _email {
    final profileEmail = _profile?['email']?.toString().trim();
    if (profileEmail?.isNotEmpty == true) return profileEmail!;
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  String? get _photoUrl {
    final profilePhoto = _profile?['user_photo']?.toString().trim();
    if (profilePhoto?.isNotEmpty == true) return profilePhoto;

    final metadataPhoto = Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['avatar_url']
        ?.toString()
        .trim();
    return metadataPhoto?.isNotEmpty == true ? metadataPhoto : null;
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
    );
  }

  void _openRecordingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GrabarPage()),
    );
  }

  void _navigateToHome(int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(initialIndex: index)),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Center(
          child: CircleAvatar(
            radius: 48,
            backgroundImage: _photoUrl == null ? null : NetworkImage(_photoUrl!),
            child: _photoUrl == null ? const Icon(Icons.person, size: 56) : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '@$_name',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProfileDetails() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.email_outlined),
          title: const Text('Correo electrónico'),
          subtitle: Text(_email),
        ),
        if (_profile?['premium'] == true)
          const ListTile(
            leading: Icon(Icons.workspace_premium_outlined),
            title: Text('Cuenta premium'),
          ),
        if (_error != null)
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('No se pudo cargar el perfil'),
            subtitle: Text(_error!),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildProfileHeader(),
            _buildProfileDetails(),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Logros',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final achievement in _achievements)
            _LockedAchievementCard(achievement: achievement),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text('Volver al mapa'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
      bottomNavigationBar: buildNavigationBar(
        selectedIndex: 4,
        onDestinationSelected: (index) {
          if (index == 2) {
            _openRecordingScreen();
          } else if (index != 4) {
            _navigateToHome(index);
          }
        },
      ),
    );
  }
}

class _LockedAchievementCard extends StatelessWidget {
  const _LockedAchievementCard({required this.achievement});

  final _Achievement achievement;

  @override
  Widget build(BuildContext context) {
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: mutedColor.withValues(alpha: 0.12),
          child: Icon(Icons.lock_outline, color: mutedColor),
        ),
        title: Row(
          children: [
            Expanded(child: Text(achievement.title)),
            Icon(achievement.icon, size: 20, color: mutedColor),
          ],
        ),
        subtitle: Text(
          '${achievement.description}\nBloqueado · ${achievement.requirement}',
          style: TextStyle(color: mutedColor),
        ),
        isThreeLine: true,
      ),
    );
  }
}

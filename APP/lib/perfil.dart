import 'package:flutter/material.dart';

import 'configuracion.dart';
import 'grabar.dart';
import 'inicio.dart';
import 'navegacion.dart';

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

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

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
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 56)),
          const SizedBox(height: 16),
          Text(
            'Mi perfil',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            '@senderista',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 24),
          const ListTile(
            leading: Icon(Icons.email_outlined),
            title: Text('Correo electrónico'),
            subtitle: Text('admin@gmail.com'),
          ),
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GrabarPage()),
            );
          } else if (index != 4) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => HomePage(initialIndex: index)),
              (route) => false,
            );
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

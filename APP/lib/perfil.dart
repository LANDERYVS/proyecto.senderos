import 'package:flutter/material.dart';

import 'grabar.dart';
import 'navegacion.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Perfil')),
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
          const Card(
            child: ListTile(
              leading: Icon(Icons.emoji_events, color: Colors.amber),
              title: Text('Primer sendero'),
              subtitle: Text('Completaste tu primer trayecto'),
            ),
          ),
          const Card(
            child: ListTile(
              leading: Icon(Icons.explore, color: Colors.green),
              title: Text('Explorador'),
              subtitle: Text('Descubre nuevos lugares'),
            ),
          ),
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
            Navigator.pop(context);
          }
        },
      ),
    );
  }
}

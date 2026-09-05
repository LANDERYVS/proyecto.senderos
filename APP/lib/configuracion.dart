import 'package:flutter/material.dart';

import 'grabar.dart';
import 'inicio.dart';
import 'navegacion.dart';

import 'services/auth_service.dart';
import 'widgets/config_card.dart';

class ConfiguracionScreen extends StatelessWidget {
  const ConfiguracionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAppConfigSection(context),
          const Divider(height: 32),
          _buildUserConfigSection(context),
          const Divider(height: 32),
          _buildSessionSection(context),
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

  /// Sección: Configuración de la App
  Widget _buildAppConfigSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Configuración de la App'),
        ConfigCard(
          icon: Icons.brightness_medium,
          title: 'Tema',
          subtitle: 'Claro (fijo)',
          onTap: () => _showMessage(context, 'Tema: Claro (fijo)'),
        ),
        ConfigCard(
          icon: Icons.notifications_outlined,
          title: 'Notificaciones',
          subtitle: 'Activadas',
          onTap: () => _showMessage(context, 'Notificaciones activadas'),
        ),
        ConfigCard(
          icon: Icons.location_on_outlined,
          title: 'Ubicación',
          subtitle: 'Activada',
          onTap: () => _showMessage(context, 'Ubicación: Activada'),
        ),
      ],
    );
  }

  /// Sección: Configuración de Usuario
  Widget _buildUserConfigSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Configuración de Usuario'),
        ConfigCard(
          icon: Icons.security_outlined,
          title: 'Privacidad',
          subtitle: 'Gestiona tu privacidad',
          onTap: () => _showMessage(context, 'Configuración de privacidad'),
        ),
      ],
    );
  }

  /// Sección: Cerrar Sesión
  Widget _buildSessionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Sesión'),
        ConfigCard(
          icon: Icons.logout,
          title: 'Cerrar Sesión',
          subtitle: 'Salir de tu cuenta',
          isDestructive: true,
          onTap: () => AuthService.showLogOutConfirmation(context),
        ),
      ],
    );
  }

  /// Título de sección reutilizable
  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  /// Muestra un mensaje temporal
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

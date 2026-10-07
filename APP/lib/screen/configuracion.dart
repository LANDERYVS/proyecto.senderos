import 'package:flutter/material.dart';

import 'grabar.dart';
import 'inicio.dart';
import '../widgets/barra_navegacion.dart';

import '../services/servicio_autenticacion.dart';
import '../services/tema_app.dart';
import '../services/ubicacion_app.dart';
import '../widgets/config_card.dart';
import 'editar_perfil.dart';
import 'localizacion.dart';

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
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => HomePage(initialIndex: index)),
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
        ValueListenableBuilder<ThemeMode>(
          valueListenable: TemaApp.themeMode,
          builder: (context, themeMode, _) {
            final isDark = themeMode == ThemeMode.dark;
            return ConfigCard(
              icon: isDark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
              title: 'Tema',
              subtitle: isDark ? 'Oscuro' : 'Claro',
              trailing: Switch(
                value: isDark,
                onChanged: (enabled) => _setDarkMode(context, enabled),
              ),
              onTap: () => _setDarkMode(context, !isDark),
            );
          },
        ),
        ValueListenableBuilder<bool>(
          valueListenable: UbicacionApp.enabled,
          builder: (context, isEnabled, _) => ConfigCard(
            icon: isEnabled
                ? Icons.location_on_outlined
                : Icons.location_off_outlined,
            title: 'Ubicación',
            subtitle: isEnabled ? 'Activada en la app' : 'Pausada en la app',
            trailing: Switch(
              value: isEnabled,
              onChanged: (enabled) =>
                  _setLocationEnabled(context, enabled),
            ),
            onTap: () => _setLocationEnabled(context, !isEnabled),
          ),
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
          icon: Icons.person_outline,
          title: 'Datos personales',
          subtitle: 'Edita tu nombre y teléfono',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditarPerfilScreen()),
          ),
        ),
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
          onTap: () => ServicioAutenticacion.showLogOutConfirmation(context),
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

  Future<void> _setDarkMode(BuildContext context, bool enabled) async {
    try {
      await TemaApp.setDarkMode(enabled);
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'No se pudo guardar el tema: $error');
    }
  }

  Future<void> _setLocationEnabled(BuildContext context, bool enabled) async {
    try {
      if (enabled) {
        final hasPermission = await LocalizacionService()
            .requestLocationPermission();
        if (!hasPermission) {
          if (context.mounted) {
            _showMessage(
              context,
              'No se activó la ubicación porque falta el permiso del sistema.',
            );
          }
          return;
        }
      }

      await UbicacionApp.setEnabled(enabled);
    } catch (error) {
      if (!context.mounted) return;
      _showMessage(context, 'No se pudo cambiar la ubicación: $error');
    }
  }
}

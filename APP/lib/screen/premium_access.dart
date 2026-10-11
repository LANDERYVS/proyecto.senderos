// Aquí se implementa una pantalla de la app.


import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/premium_access_service.dart';
// La clase PremiumAccessScreen reúne los datos y las acciones de esta parte de la app.

class PremiumAccessScreen extends StatefulWidget {
  const PremiumAccessScreen({super.key});

  @override
  State<PremiumAccessScreen> createState() => _PremiumAccessScreenState();
}
// La clase _PremiumAccessScreenState reúne los datos y las acciones de esta parte de la app.

class _PremiumAccessScreenState extends State<PremiumAccessScreen> {
  final PremiumAccessService _premiumAccessService = PremiumAccessService();
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isPremium = false;
  String? _errorMessage;
// Al abrir esta pantalla, se cargan los datos iniciales y se preparan las suscripciones necesarias.

  @override
  void initState() {
    super.initState();
    _loadPremiumAccess();
  }
// Carga los datos necesarios para mostrar la información más reciente.

  Future<void> _loadPremiumAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Inicia sesión para gestionar el acceso Premium.';
      });
      return;
    }

    try {
      final hasAccess = await _premiumAccessService.hasAccess();
      if (!mounted) return;
      setState(() {
        _isPremium = hasAccess;
        _isLoading = false;
        _errorMessage = null;
      });
    } on Exception catch (error) {
      debugPrint('No se pudo cargar el acceso premium: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'No se pudo cargar el estado Premium.';
      });
    }
  }

  Future<void> _setPremium(bool value) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || _isSaving) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final saved = await _premiumAccessService.saveLocalOverride(
        user.id,
        value,
      );
      if (!saved) {
        debugPrint('No se pudo guardar el estado Premium.');
        if (mounted) {
          setState(
            () => _errorMessage = 'No se pudo guardar el estado Premium.',
          );
        }
        return;
      }
      if (!mounted) return;
      setState(() {
        _isPremium = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? 'Premium activado.' : 'Premium desactivado.'),
        ),
      );
    } on Exception catch (error) {
      debugPrint('No se pudo guardar el estado Premium: $error');
      if (!mounted) return;
      setState(() => _errorMessage = 'No se pudo guardar el estado Premium.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _buildBenefit(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: colors.primaryContainer,
            child: Icon(icon, color: colors.onPrimaryContainer),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
// Construye la interfaz de esta pantalla con los datos y filtros actuales.

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('THOPO Premium')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            margin: EdgeInsets.zero,
            color: colors.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.workspace_premium_rounded,
                    size: 36,
                    color: colors.onTertiaryContainer,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Explora con Premium',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Desbloquea herramientas para preparar y disfrutar tus rutas.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colors.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Beneficios incluidos',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _buildBenefit(
            context,
            icon: Icons.cloud_outlined,
            title: 'Clima del sendero',
            description:
                'Consulta las condiciones actuales y el pronóstico para planificar tu salida.',
          ),
          _buildBenefit(
            context,
            icon: Icons.download_for_offline_outlined,
            title: 'Descargas sin conexión',
            description:
                'Guarda el GPX y el mapa del sendero para usarlos cuando no tengas internet.',
          ),
          const SizedBox(height: 16),
          Card(
            margin: EdgeInsets.zero,
            child: _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SwitchListTile(
                    secondary: Icon(
                      Icons.workspace_premium_outlined,
                      color: colors.primary,
                    ),
                    title: const Text(
                      'Activar Premium',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _isPremium
                          ? 'Premium está activado en este dispositivo.'
                          : 'Activa el acceso a clima y descargas offline.',
                    ),
                    value: _isPremium,
                    onChanged: _isSaving || _errorMessage != null
                        ? null
                        : _setPremium,
                  ),
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LinearProgressIndicator(),
            ),
          if (_errorMessage case final error?) ...[
            const SizedBox(height: 12),
            Text(error, style: TextStyle(color: colors.error)),
            if (Supabase.instance.client.auth.currentUser != null)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isSaving ? null : _loadPremiumAccess,
                  child: const Text('Reintentar'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

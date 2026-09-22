import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../screen/inicio.dart';
import '../widgets/login.dart';

/// Servicio centralizado para todas las operaciones de autenticación.
class ServicioAutenticacion {
  static final _supabase = Supabase.instance.client;

  static Future<String?> login(String identifier, String password) async {
    try {
      var email = identifier.trim();

      if (email.isEmpty || password.isEmpty) {
        return 'Completa el correo y la contraseña';
      }

      if (!email.contains('@')) {
        final profile = await _supabase
            .from('usuarios')
            .select('email')
            .eq('name', email)
            .maybeSingle();
        email = profile?['email'] as String? ?? email;
        if (!email.contains('@')) {
          return 'No se encontró un usuario con ese nombre';
        }
      }

      await _supabase.auth.signInWithPassword(email: email, password: password);
      try {
        await syncCurrentUserProfile();
      } on Exception catch (error) {
        debugPrint('No se pudo sincronizar el perfil: $error');
      }
      return _supabase.auth.currentSession != null
          ? null
          : 'No se pudo iniciar la sesión';
    } on AuthException catch (error) {
      return error.message;
    } on PostgrestException catch (error) {
      return 'Error al consultar el usuario: ${error.message}';
    } catch (error) {
      return 'Error inesperado al iniciar sesión: $error';
    }
  }

  static Future<void> syncCurrentUserProfile() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final username = (metadata['username'] ?? metadata['name'] ?? '')
        .toString()
        .trim();

    await _supabase.from('usuarios').upsert({
      'id': user.id,
      'name': username.isEmpty ? (user.email ?? 'Usuario') : username,
      'email': user.email,
      'admin': false,
      'premium': false,
    }, onConflict: 'id');
  }

  static Future<String?> createAccount(
    String email,
    String username,
    String password,
    String confirmPassword,
  ) async {
    if (email.isEmpty || !email.contains('@')) {
      return 'Escribe un correo válido';
    }
    if (username.isEmpty) return 'Escribe un nombre de usuario';
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (password != confirmPassword) {
      return 'Las contraseñas no coinciden';
    }

    try {
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': username.trim(), 'username': username.trim()},
      );
      final user = response.user;
      if (user == null) return 'No se pudo crear la cuenta';

      await _supabase.from('usuarios').insert({
        'id': user.id,
        'name': username.trim(),
        'email': email.trim(),
        'admin': false,
        'premium': false,
      });

      return null;
    } on AuthException catch (error) {
      return error.message;
    } on PostgrestException catch (error) {
      return 'No se pudo guardar el perfil: ${error.message}';
    }
  }

  static Future<void> logOut(BuildContext context) async {
    await _supabase.auth.signOut();

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(home: HomePage())),
      (route) => false,
    );
  }

  static void showLogOutConfirmation(BuildContext context) {
    showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context, true);
              logOut(context);
            },
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }
}

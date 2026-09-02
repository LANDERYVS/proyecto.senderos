import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../grabar.dart';
import '../inicio.dart';
import '../login.dart';

/// Servicio centralizado para TODAS las operaciones de autenticación
class AuthService {
  // Credenciales registradas
  static String _registeredEmail = 'admin@gmail.com';
  static String _registeredUsername = 'admin';
  static String _registeredPassword = '123456';

  // Getters
  static String get registeredEmail => _registeredEmail;
  static String get registeredUsername => _registeredUsername;
  static String get registeredPassword => _registeredPassword;

  /// Carga las credenciales guardadas en SharedPreferences
  static Future<void> loadRegisteredAccount() async {
    final preferences = await SharedPreferences.getInstance();
    _registeredEmail =
        preferences.getString('registeredEmail') ?? _registeredEmail;
    _registeredUsername =
        preferences.getString('registeredUsername') ?? _registeredUsername;
    _registeredPassword =
        preferences.getString('registeredPassword') ?? _registeredPassword;
  }

  /// Valida las credenciales y realiza login
  static Future<bool> login(String identifier, String password) async {
    final validIdentifier =
        identifier == _registeredEmail || identifier == _registeredUsername;

    if (validIdentifier && password == _registeredPassword) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('isLoggedIn', true);
      return true;
    }
    return false;
  }

  /// Crea una nueva cuenta
  static Future<String?> createAccount(
    String email,
    String username,
    String password,
    String confirmPassword,
  ) async {
    // Validaciones
    if (email.isEmpty || !email.contains('@')) {
      return 'Escribe un correo válido';
    }
    if (username.isEmpty) {
      return 'Escribe un nombre de usuario';
    }
    if (password.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (password != confirmPassword) {
      return 'Las contraseñas no coinciden';
    }

    // Guardar en SharedPreferences
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('registeredEmail', email);
    await preferences.setString('registeredUsername', username);
    await preferences.setString('registeredPassword', password);

    // Actualizar variables locales
    _registeredEmail = email;
    _registeredUsername = username;
    _registeredPassword = password;

    return null; // Sin error
  }

  /// Realiza logout del usuario y navega a login
  static Future<void> logOut(BuildContext context) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('isLoggedIn', false);

    if (!context.mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen(home: HomePage())),
      (route) => false,
    );
  }

  /// Muestra diálogo de confirmación para logout
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

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/servicio_autenticacion.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.home});

  final Widget home;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _loadSession();
  }

  Future<void> _loadSession() async {
    if (!mounted) return;
    if (Supabase.instance.client.auth.currentSession != null) {
      try {
        await ServicioAutenticacion.syncCurrentUserProfile();
      } on Exception {
        // La pantalla de login seguirá permitiendo reintentar la sesión.
      }
    }
    if (!mounted) return;
    setState(() {
      _isLoggedIn = Supabase.instance.client.auth.currentSession != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _isLoggedIn ? widget.home : LoginScreen(home: widget.home);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.home});

  final Widget home;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isCreatingAccount = false;

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final loginIdentifier = emailController.text.trim();
    final password = passwordController.text;

    final error = await ServicioAutenticacion.login(loginIdentifier, password);

    if (!mounted) return;

    if (error == null) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.home),
      );
    } else {
      _showMessage(error);
    }
  }

  Future<void> _createAccount() async {
    final email = emailController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    final error = await ServicioAutenticacion.createAccount(
      email,
      username,
      password,
      confirmPassword,
    );

    if (!mounted) return;

    if (error != null) {
      _showMessage(error);
    } else {
      setState(() {
        isCreatingAccount = false;
        usernameController.clear();
        passwordController.clear();
        confirmPasswordController.clear();
      });
      _showMessage('Cuenta creada. Ya puedes iniciar sesión');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isCreatingAccount ? 'Crear cuenta' : 'Iniciar sesión'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Correo o nombre de usuario',
                border: OutlineInputBorder(),
              ),
            ),
            if (isCreatingAccount) ...[
              const SizedBox(height: 16),
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nombre de usuario',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                border: OutlineInputBorder(),
              ),
            ),
            if (isCreatingAccount) ...[
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isCreatingAccount ? _createAccount : _login,
                child: Text(
                  isCreatingAccount ? 'Crear cuenta' : 'Iniciar sesión',
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  isCreatingAccount = !isCreatingAccount;
                  usernameController.clear();
                  passwordController.clear();
                  confirmPasswordController.clear();
                });
              },
              child: Text(
                isCreatingAccount
                    ? 'Ya tengo una cuenta'
                    : 'No tengo una cuenta, crear una',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

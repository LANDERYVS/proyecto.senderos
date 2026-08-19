import 'package:flutter/material.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.home});

  final Widget home;

  @override
  Widget build(BuildContext context) {
    return LoginScreen(home: home);
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
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  bool isCreatingAccount = false;
  String registeredEmail = 'admin@gmail.com';
  String registeredPassword = '123456';

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  void _login() {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email == registeredEmail && password == registeredPassword) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.home),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Correo o contraseña incorrectos'),
        ),
      );
    }
  }

  void _createAccount() {
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Escribe un correo válido');
      return;
    }
    if (password.length < 6) {
      _showMessage('La contraseña debe tener al menos 6 caracteres');
      return;
    }
    if (password != confirmPassword) {
      _showMessage('Las contraseñas no coinciden');
      return;
    }

    setState(() {
      registeredEmail = email;
      registeredPassword = password;
      isCreatingAccount = false;
      passwordController.clear();
      confirmPasswordController.clear();
    });
    _showMessage('Cuenta creada. Ya puedes iniciar sesión');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                labelText: 'Correo',
                border: OutlineInputBorder(),
              ),
            ),
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
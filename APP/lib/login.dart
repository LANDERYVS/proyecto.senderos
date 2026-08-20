import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = preferences.getBool('isLoggedIn') ?? false;
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
  String registeredEmail = 'admin@gmail.com';
  String registeredUsername = 'admin';
  String registeredPassword = '123456';

  @override
  void initState() {
    super.initState();
    _loadRegisteredAccount();
  }

  Future<void> _loadRegisteredAccount() async {
    final preferences = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      registeredEmail =
          preferences.getString('registeredEmail') ?? registeredEmail;
      registeredUsername =
          preferences.getString('registeredUsername') ?? registeredUsername;
      registeredPassword =
          preferences.getString('registeredPassword') ?? registeredPassword;
    });
  }

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

    final validIdentifier =
        loginIdentifier == registeredEmail ||
        loginIdentifier == registeredUsername;

    if (validIdentifier && password == registeredPassword) {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setBool('isLoggedIn', true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => widget.home),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Correo o contraseña incorrectos')),
      );
    }
  }

  Future<void> _createAccount() async {
    final email = emailController.text.trim();
    final username = usernameController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (email.isEmpty || !email.contains('@')) {
      _showMessage('Escribe un correo válido');
      return;
    }
    if (username.isEmpty) {
      _showMessage('Escribe un nombre de usuario');
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

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('registeredEmail', email);
    await preferences.setString('registeredUsername', username);
    await preferences.setString('registeredPassword', password);
    if (!mounted) return;
    setState(() {
      registeredEmail = email;
      registeredUsername = username;
      registeredPassword = password;
      isCreatingAccount = false;
      usernameController.clear();
      passwordController.clear();
      confirmPasswordController.clear();
    });
    _showMessage('Cuenta creada. Ya puedes iniciar sesión');
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

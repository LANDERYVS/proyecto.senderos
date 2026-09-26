import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/servicio_autenticacion.dart';
import 'login_styles.dart';

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
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedAvatar;
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

  Future<void> _pickProfileImage() async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );

    if (!mounted || image == null) return;

    setState(() {
      _selectedAvatar = image;
    });
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
      backgroundColor: const Color(0xFFEAE1D2),
      body: Container(
        decoration: const BoxDecoration(gradient: LoginStyles.screenGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(235),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(35),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LoginStyles.buildLogo(),
                    const SizedBox(height: 28),
                    if (isCreatingAccount) ...[
                      LoginStyles.buildProfileAvatarSelector(
                        selectedAvatar: _selectedAvatar,
                        onPick: _pickProfileImage,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (isCreatingAccount)
                      LoginStyles.buildInputField(
                        controller: usernameController,
                        labelText: 'Nombre de usuario',
                      ),
                    if (isCreatingAccount) const SizedBox(height: 16),
                    LoginStyles.buildInputField(
                      controller: emailController,
                      labelText: 'Correo o nombre de usuario',
                    ),
                    const SizedBox(height: 16),
                    LoginStyles.buildInputField(
                      controller: passwordController,
                      labelText: 'Contraseña',
                      obscureText: true,
                    ),
                    if (isCreatingAccount) ...[
                      const SizedBox(height: 16),
                      LoginStyles.buildInputField(
                        controller: confirmPasswordController,
                        labelText: 'Confirmar contraseña',
                        obscureText: true,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isCreatingAccount ? _createAccount : _login,
                        style: LoginStyles.actionButtonStyle(),
                        child: Text(
                          isCreatingAccount ? 'Crear cuenta' : 'Iniciar sesión',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          isCreatingAccount = !isCreatingAccount;
                          usernameController.clear();
                          passwordController.clear();
                          confirmPasswordController.clear();
                          _selectedAvatar = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2E5E47),
                      ),
                      child: Text(
                        isCreatingAccount
                            ? 'Ya tengo una cuenta'
                            : 'No tengo una cuenta, crear una',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

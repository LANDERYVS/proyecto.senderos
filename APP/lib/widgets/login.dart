// Aquí se define un componente visual reutilizable.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/servicio_autenticacion.dart';
import '../app_styles.dart';
// La clase AuthGate reúne los datos y las acciones de esta parte de la app.

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.home});

  final Widget home;

  @override
  State<AuthGate> createState() => _AuthGateState();
}
// La clase _AuthGateState reúne los datos y las acciones de esta parte de la app.

class _AuthGateState extends State<AuthGate> {
  bool _isLoggedIn = false;
  // Al abrir esta pantalla, se cargan los datos iniciales y se preparan las suscripciones necesarias.

  @override
  void initState() {
    super.initState();
    _loadSession();
  }
  // Carga los datos necesarios para mostrar la información más reciente.

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
  // Construye la interfaz de esta pantalla con los datos y filtros actuales.

  @override
  Widget build(BuildContext context) {
    return _isLoggedIn ? widget.home : LoginScreen(home: widget.home);
  }
}
// La clase LoginScreen reúne los datos y las acciones de esta parte de la app.

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.home});

  final Widget home;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}
// La clase _LoginScreenState reúne los datos y las acciones de esta parte de la app.

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final usernameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedAvatar;
  bool isCreatingAccount = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  // Al salir de esta pantalla, se cancelan las tareas activas y se liberan sus recursos.

  @override
  void dispose() {
    emailController.dispose();
    usernameController.dispose();
    phoneController.dispose();
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
    final phone = phoneController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    final error = await ServicioAutenticacion.createAccount(
      email,
      username,
      phone,
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
        phoneController.clear();
        passwordController.clear();
        confirmPasswordController.clear();
      });
      _showMessage('Cuenta creada. Ya puedes iniciar sesión');
    }
  }
  // Muestra al usuario las opciones o el aviso que corresponde a esta acción.

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
  // Construye la interfaz de esta pantalla con los datos y filtros actuales.

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF202923).withAlpha(245)
                      : Colors.white.withAlpha(235),
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
                    AppStyles.buildLogo(context),
                    const SizedBox(height: 28),
                    if (isCreatingAccount) ...[
                      AppStyles.buildProfileAvatarSelector(
                        context: context,
                        selectedAvatar: _selectedAvatar,
                        onPick: _pickProfileImage,
                      ),
                      const SizedBox(height: 20),
                    ],
                    if (isCreatingAccount)
                      AppStyles.buildInputField(
                        context: context,
                        controller: usernameController,
                        labelText: 'Nombre de usuario *',
                      ),
                    if (isCreatingAccount) const SizedBox(height: 16),
                    if (isCreatingAccount)
                      AppStyles.buildInputField(
                        context: context,
                        controller: phoneController,
                        labelText: 'Número de teléfono *',
                        keyboardType: TextInputType.phone,
                      ),
                    if (isCreatingAccount) const SizedBox(height: 16),
                    AppStyles.buildInputField(
                      context: context,
                      controller: emailController,
                      labelText: isCreatingAccount
                          ? 'Correo electrónico *'
                          : 'Correo o nombre de usuario',
                    ),
                    const SizedBox(height: 16),
                    AppStyles.buildInputField(
                      context: context,
                      controller: passwordController,
                      labelText: isCreatingAccount
                          ? 'Contraseña *'
                          : 'Contraseña',
                      obscureText: !_isPasswordVisible,
                      suffixIcon: IconButton(
                        tooltip: _isPasswordVisible
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        onPressed: () => setState(
                          () => _isPasswordVisible = !_isPasswordVisible,
                        ),
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                    if (isCreatingAccount) ...[
                      const SizedBox(height: 16),
                      AppStyles.buildInputField(
                        context: context,
                        controller: confirmPasswordController,
                        labelText: 'Confirmar contraseña *',
                        obscureText: !_isConfirmPasswordVisible,
                        suffixIcon: IconButton(
                          tooltip: _isConfirmPasswordVisible
                              ? 'Ocultar contraseña'
                              : 'Mostrar contraseña',
                          onPressed: () => setState(
                            () => _isConfirmPasswordVisible =
                                !_isConfirmPasswordVisible,
                          ),
                          icon: Icon(
                            _isConfirmPasswordVisible
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: isCreatingAccount ? _createAccount : _login,
                        style: AppStyles.actionButtonStyle(context),
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
                          phoneController.clear();
                          passwordController.clear();
                          confirmPasswordController.clear();
                          _selectedAvatar = null;
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? colorScheme.primary
                            : const Color(0xFF2E5E47),
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
    );
  }
}

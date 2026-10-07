import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  bool _isSaving = false;
  String? _email;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('Debes iniciar sesión para editar tus datos.');
      return;
    }

    try {
      final profile = await _client
          .from('usuarios')
          .select('name, telefono')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      if (profile == null) {
        setState(() => _isLoading = false);
        _showMessage('No se encontró tu perfil de usuario.');
        return;
      }

      _nameController.text =
          profile['name']?.toString() ??
          user.userMetadata?['name']?.toString() ??
          '';
      _phoneController.text = profile['telefono']?.toString() ?? '';
      setState(() {
        _email = user.email;
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('No se pudieron cargar tus datos: ${error.message}');
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage('No se pudieron cargar tus datos: $error');
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Escribe tu nombre';
    if (name.length > 80) return 'El nombre no puede superar 80 caracteres';
    return null;
  }

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return 'Escribe tu teléfono';
    if (digits.length < 7 || digits.length > 15) {
      return 'Escribe un teléfono válido';
    }
    return null;
  }

  Future<void> _saveProfile() async {
    if (_isSaving || !(_formKey.currentState?.validate() ?? false)) return;

    final user = _client.auth.currentUser;
    if (user == null) {
      _showMessage('Tu sesión expiró. Inicia sesión nuevamente.');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final updatedProfile = await _client
          .from('usuarios')
          .update({
            'name': _nameController.text.trim(),
            'telefono': _phoneController.text.trim(),
          })
          .eq('id', user.id)
          .select('id')
          .maybeSingle();

      if (updatedProfile == null) {
        throw const _ProfileUpdateException(
          'No se pudo actualizar tu perfil. Comprueba que la política RLS '
          'permita actualizar tu propia fila.',
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tus datos se actualizaron correctamente'),
        ),
      );
      Navigator.pop(context, true);
    } on _ProfileUpdateException catch (error) {
      _showMessage(error.message);
    } on PostgrestException catch (error) {
      _showMessage('No se pudieron guardar tus datos: ${error.message}');
    } catch (error) {
      _showMessage('No se pudieron guardar tus datos: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datos personales')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Mantén actualizada la información de tu cuenta.'),
                const SizedBox(height: 24),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 80,
                        validator: _validateName,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          prefixIcon: Icon(Icons.person_outline),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 30,
                        validator: _validatePhone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                          prefixIcon: Icon(Icons.phone_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        initialValue: _email ?? '',
                        readOnly: true,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                          helperText:
                              'El correo de acceso no se cambia desde este apartado.',
                          prefixIcon: Icon(Icons.email_outlined),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton.icon(
                        onPressed: _isSaving ? null : _saveProfile,
                        icon: _isSaving
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: Text(
                          _isSaving ? 'Guardando...' : 'Guardar cambios',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _ProfileUpdateException implements Exception {
  const _ProfileUpdateException(this.message);

  final String message;
}

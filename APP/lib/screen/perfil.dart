import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/almacenamiento_r2.dart';
import '../services/servicio_autenticacion.dart';
import '../models/explore_trail.dart';
import 'configuracion.dart';
import 'grabar.dart';
import 'inicio.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/default_user_avatar.dart';

class _ProfilePhotoSaveException implements Exception {
  const _ProfilePhotoSaveException(this.message);

  final String message;
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _isUploadingPhoto = false;
  String? _error;
  final ImagePicker _imagePicker = ImagePicker();
  final AlmacenamientoR2 _almacenamientoR2 = AlmacenamientoR2();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No hay una sesión iniciada';
      });
      return;
    }

    try {
      await ServicioAutenticacion.syncCurrentUserProfile();

      final profile = await Supabase.instance.client
          .from('usuarios')
          .select('name, email, user_photo, premium')
          .eq('id', user.id)
          .maybeSingle();

      final fallbackProfile = {
        'name':
            user.userMetadata?['name'] ??
            user.userMetadata?['username'] ??
            user.email ??
            'Usuario',
        'email': user.email ?? '',
        'user_photo': user.userMetadata?['avatar_url'],
        'premium': false,
      };

      if (!mounted) return;
      setState(() {
        _profile = profile ?? fallbackProfile;
        _isLoading = false;
        _error = null;
      });
    } on PostgrestException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'No se pudo cargar el perfil.';
      });
    }
  }

  String get _name {
    final profileName = _profile?['name']?.toString().trim();
    if (profileName?.isNotEmpty == true) return profileName!;

    final metadata = Supabase.instance.client.auth.currentUser?.userMetadata;
    final metadataName = (metadata?['name'] ?? metadata?['username'])
        ?.toString()
        .trim();
    return metadataName?.isNotEmpty == true ? metadataName! : 'Usuario';
  }

  String get _email {
    final profileEmail = _profile?['email']?.toString().trim();
    if (profileEmail?.isNotEmpty == true) return profileEmail!;
    return Supabase.instance.client.auth.currentUser?.email ?? '';
  }

  String? get _photoUrl {
    final profilePhoto = _profile?['user_photo']?.toString().trim();
    if (profilePhoto?.isNotEmpty == true) {
      return ExploreTrail.publicR2Url(profilePhoto);
    }

    final metadataPhoto = Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['avatar_url']
        ?.toString()
        .trim();
    return metadataPhoto?.isNotEmpty == true ? metadataPhoto : null;
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ConfiguracionScreen()),
    );
  }

  void _openRecordingScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const GrabarPage()),
    );
  }

  void _navigateToHome(int index) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(initialIndex: index)),
    );
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _imageContentType(String path) {
    final extension = path.split('.').last.toLowerCase();
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }

  Future<void> _changeProfilePhoto() async {
    if (_isUploadingPhoto) return;

    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (pickedFile == null || !mounted) return;

      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        _showMessage('Debes iniciar sesión para cambiar la foto');
        return;
      }

      setState(() => _isUploadingPhoto = true);

      final photoKey = await _almacenamientoR2.uploadFileToR2(
        file: File(pickedFile.path),
        folder: 'foto_usuarios',
        contentType: _imageContentType(pickedFile.path),
      );

      try {
        final updatedProfile = await Supabase.instance.client
            .from('usuarios')
            .update({'user_photo': photoKey})
            .eq('id', user.id)
            .select('id')
            .maybeSingle();

        if (updatedProfile == null) {
          throw const _ProfilePhotoSaveException(
            'La foto se subió a R2, pero no se actualizó ninguna fila de usuarios. Revisa que exista el perfil con ese id y que la política RLS permita al usuario actualizar su propia fila.',
          );
        }
      } on PostgrestException {
        throw const _ProfilePhotoSaveException(
          'No se pudo actualizar la foto.',
        );
      }

      if (!mounted) return;
      setState(() {
        _profile = {...?_profile, 'user_photo': photoKey};
      });
      _showMessage('Foto de perfil actualizada');
    } on R2UploadException {
      _showMessage('No se pudo actualizar la foto.');
    } on _ProfilePhotoSaveException catch (error) {
      _showMessage(error.message);
    } on FileSystemException {
      _showMessage(
        'No se pudo leer la imagen del dispositivo. Vuelve a elegir una foto que siga disponible.',
      );
    } on SocketException {
      _showMessage('No hay conexión a internet.');
    } on HttpException {
      _showMessage('No hay conexión a internet.');
    } on TimeoutException {
      _showMessage('No hay conexión a internet.');
    } on PlatformException {
      _showMessage('No se pudo abrir la galería.');
    } catch (error) {
      _showMessage('No se pudo actualizar la foto.');
    } finally {
      if (mounted && _isUploadingPhoto) {
        setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Center(
          child: Stack(
            alignment: Alignment.bottomRight,
            children: [
              _photoUrl == null
                  ? DefaultUserAvatar(radius: 48)
                  : CircleAvatar(
                      radius: 48,
                      backgroundImage: NetworkImage(_photoUrl!),
                    ),
              if (_isUploadingPhoto)
                const Padding(
                  padding: EdgeInsets.all(4),
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: InkWell(
                    onTap: _changeProfilePhoto,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF2E7D32),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          _name,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '@$_name',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildProfileDetails() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.email_outlined),
          title: const Text('Correo electrónico'),
          subtitle: Text(_email),
        ),
        if (_profile?['premium'] == true)
          const ListTile(
            leading: Icon(Icons.workspace_premium_outlined),
            title: Text('Cuenta premium'),
          ),
        if (_error != null)
          ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('No se pudo cargar el perfil'),
            subtitle: Text(_error!),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            tooltip: 'Configuración',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildProfileHeader(),
            _buildProfileDetails(),
          ],
          const Divider(),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text('Volver al mapa'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
      bottomNavigationBar: buildNavigationBar(
        selectedIndex: 4,
        onDestinationSelected: (index) {
          if (index == 2) {
            _openRecordingScreen();
          } else {
            _navigateToHome(index);
          }
        },
      ),
    );
  }
}

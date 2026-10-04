import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/almacenamiento_r2.dart';
import '../models/explore_trail.dart';
import 'configuracion.dart';
import 'grabar.dart';
import 'inicio.dart';
import 'logros_screen.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/default_user_avatar.dart';
import '../widgets/login_styles.dart';

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
  int _publishedTrails = 0;
  double _distanceKm = 0;
  int _unlockedAchievements = 0;
  final ImagePicker _imagePicker = ImagePicker();
  final AlmacenamientoR2 _almacenamientoR2 = AlmacenamientoR2();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _loadActivityStats();
  }

  Future<void> _loadProfile() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('No se pudo cargar el perfil: no hay una sesión iniciada.');
      return;
    }

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

    try {
      final profile = await Supabase.instance.client
          .from('usuarios')
          .select('name, email, user_photo, premium')
          .eq('id', user.id)
          .maybeSingle();

      if (!mounted) return;
      setState(() {
        _profile = profile ?? fallbackProfile;
        _isLoading = false;
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _profile = fallbackProfile;
        _isLoading = false;
      });
      debugPrint('No se pudo cargar el perfil: $error');
    }
  }

  Future<void> _loadActivityStats() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final trailRows = await Supabase.instance.client
          .from('senderos')
          .select('id, distancia')
          .eq('user_id', user.id);
      final achievementRows = await Supabase.instance.client
          .from('user_logros')
          .select('logro_id')
          .eq('user_id', user.id);

      var distance = 0.0;
      for (final row in trailRows) {
        distance += (row['distancia'] as num?)?.toDouble() ?? 0;
      }

      if (!mounted) return;
      setState(() {
        _publishedTrails = trailRows.length;
        _distanceKm = distance;
        _unlockedAchievements = achievementRows.length;
      });
    } on PostgrestException catch (error) {
      debugPrint('No se pudieron cargar las estadísticas del perfil: $error');
    } catch (error) {
      debugPrint('No se pudieron cargar las estadísticas del perfil: $error');
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

  void _openAchievements() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LogrosScreen()),
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
        objectPrefix: DateTime.now().microsecondsSinceEpoch.toString(),
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
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [LoginStyles.deepGreen, LoginStyles.forestGreen],
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: LoginStyles.deepGreen.withAlpha(35),
                blurRadius: 18,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            children: [
              Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: LoginStyles.accentGold,
                      shape: BoxShape.circle,
                    ),
                    child: DefaultUserAvatar(radius: 48, imageUrl: _photoUrl),
                  ),
                  Material(
                    color: LoginStyles.accentGold,
                    shape: const CircleBorder(),
                    child: InkWell(
                      onTap: _isUploadingPhoto ? null : _changeProfilePhoto,
                      customBorder: const CircleBorder(),
                      child: SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: _isUploadingPhoto
                              ? const SizedBox.square(
                                  dimension: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: LoginStyles.deepGreen,
                                  ),
                                )
                              : const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 18,
                                  color: LoginStyles.deepGreen,
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                _name,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_profile?['premium'] == true) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: LoginStyles.accentGold.withAlpha(30),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: LoginStyles.accentGold.withAlpha(150),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.workspace_premium_rounded,
                        size: 16,
                        color: LoginStyles.accentGold,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'THOPO PREMIUM',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                const SizedBox(height: 6),
                Text(
                  'Senderista THOPO',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withAlpha(210),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildActivityStats() {
    return Row(
      children: [
        _ProfileStatCard(
          icon: Icons.route_outlined,
          value: '$_publishedTrails',
          label: 'Senderos',
        ),
        const SizedBox(width: 10),
        _ProfileStatCard(
          icon: Icons.terrain_outlined,
          value: _distanceKm.toStringAsFixed(1),
          label: 'Kilómetros',
        ),
        const SizedBox(width: 10),
        _ProfileStatCard(
          icon: Icons.emoji_events_outlined,
          value: '$_unlockedAchievements',
          label: 'Logros',
        ),
      ],
    );
  }

  Widget _buildProfileDetails() {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 24, 4, 10),
          child: Text(
            'Mi cuenta',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: LoginStyles.softCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colors.outlineVariant.withAlpha(120)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 5,
            ),
            leading: CircleAvatar(
              backgroundColor: LoginStyles.primaryGreen.withAlpha(20),
              child: const Icon(
                Icons.email_outlined,
                color: LoginStyles.primaryGreen,
              ),
            ),
            title: const Text(
              'Correo electrónico',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(_email),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: LoginStyles.softCream,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: colors.outlineVariant.withAlpha(120)),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 5,
            ),
            leading: CircleAvatar(
              backgroundColor: LoginStyles.accentGold.withAlpha(45),
              child: const Icon(
                Icons.emoji_events_outlined,
                color: LoginStyles.deepGreen,
              ),
            ),
            title: const Text(
              'Mis logros',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '$_unlockedAchievements logros desbloqueados · Ver progreso',
            ),
            trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            onTap: _openAchievements,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: LoginStyles.primaryGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 5,
            ),
            leading: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(
                Icons.settings_outlined,
                color: LoginStyles.primaryGreen,
              ),
            ),
            title: const Text(
              'Configuración',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Preferencias y opciones de la cuenta',
              style: TextStyle(color: Colors.white.withAlpha(220)),
            ),
            trailing: const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 16,
              color: Colors.white,
            ),
            onTap: _openSettings,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else ...[
            _buildProfileHeader(),
            _buildActivityStats(),
            _buildProfileDetails(),
          ],
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

class _ProfileStatCard extends StatelessWidget {
  const _ProfileStatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 14),
        decoration: BoxDecoration(
          color: LoginStyles.softCream,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withAlpha(120),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: LoginStyles.primaryGreen, size: 21),
            const SizedBox(height: 7),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: LoginStyles.deepGreen,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
      ),
    );
  }
}

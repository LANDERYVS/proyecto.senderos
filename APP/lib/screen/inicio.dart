import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/explore_trail.dart';
import '../services/compartir_ubicacion.dart';
import '../services/logros_service.dart';
import 'amigos.dart';
import 'guardados.dart';
import 'explorar.dart';
import 'espectador.dart';
import 'grabar.dart';
import 'notificaciones.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/default_user_avatar.dart';
import '../widgets/search_field.dart';
import 'perfil.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _client = Supabase.instance.client;
  final _sharingService = CompartirUbicacionService();
  late int _selectedIndex;
  int _communityVersion = 0;
  int _notificationCount = 0;
  String _exploreSearchTerm = '';
  String _friendsSearchTerm = '';
  String _savedSearchTerm = '';
  bool _filtersExpanded = false;
  String? _userPhotoUrl;
  RealtimeChannel? _notificationChannel;
  Timer? _notificationRefreshTimer;
  Timer? _achievementRefreshTimer;
  bool _checkingAchievements = false;
  bool _hasSharedLocation = false;
  bool _checkingSharedLocation = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _selectedIndex = widget.initialIndex.clamp(0, 4);
    _loadCurrentUserPhoto();
    _loadNotificationCount();
    _loadSharedLocationStatus();
    _checkAchievements();
    _subscribeToNotifications();
    _notificationRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) {
        _loadNotificationCount();
        _loadSharedLocationStatus();
      },
    );
    _achievementRefreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _checkAchievements(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationRefreshTimer?.cancel();
    _achievementRefreshTimer?.cancel();
    _sharingService.dispose();
    final channel = _notificationChannel;
    if (channel != null) {
      _client.removeChannel(channel);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNotificationCount();
      _loadSharedLocationStatus();
      _checkAchievements();
    }
  }

  Future<void> _loadSharedLocationStatus() async {
    if (!mounted ||
        _checkingSharedLocation ||
        _client.auth.currentUser == null) {
      return;
    }

    _checkingSharedLocation = true;
    try {
      final groups = await _sharingService.loadObservedTrails();
      final hasSharedLocation = groups.any(
        (group) => group.observers.any((observer) => observer.location != null),
      );
      if (mounted && hasSharedLocation != _hasSharedLocation) {
        setState(() => _hasSharedLocation = hasSharedLocation);
      }
    } catch (error) {
      debugPrint('No se pudo comprobar si hay ubicaciones compartidas: $error');
    } finally {
      _checkingSharedLocation = false;
    }
  }

  Future<void> _checkAchievements() async {
    if (!mounted || _checkingAchievements || _client.auth.currentUser == null) {
      return;
    }

    _checkingAchievements = true;
    LogrosSession? session;
    try {
      session = await LogrosService(client: _client).loadAndSync();
      if (mounted && session.newlyUnlocked.isNotEmpty) {
        await showLogroNotifications(context, session.newlyUnlocked);
      }
    } catch (error) {
      debugPrint('No se pudieron comprobar los logros: $error');
    } finally {
      session?.controller.dispose();
      _checkingAchievements = false;
    }
  }

  void _subscribeToNotifications() {
    final user = _client.auth.currentUser;
    if (user == null) return;

    _notificationChannel = _client
        .channel('notifications:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones_alertas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'espectador_id',
            value: user.id,
          ),
          callback: (_) => _loadNotificationCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones_solicitudes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_id',
            value: user.id,
          ),
          callback: (_) => _loadNotificationCount(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones_espectador',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_id',
            value: user.id,
          ),
          callback: (_) => _loadNotificationCount(),
        )
        .subscribe();
  }

  Future<void> _loadNotificationCount() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final globalNotifications = await _client
          .from('notificaciones_alertas')
          .select('id, status')
          .eq('espectador_id', user.id);
      final receivedRequests = await _client
          .from('notificaciones_solicitudes')
          .select('id')
          .eq('target_id', user.id);
      final receivedLocationRequests = await _client
          .from('notificaciones_espectador')
          .select('id')
          .eq('target_id', user.id)
          .eq('estado', 'pendiente');
      if (!mounted) return;

      final unreadGlobalCount = globalNotifications
          .where((notification) => notification['status'] != true)
          .length;
      setState(
        () => _notificationCount =
            unreadGlobalCount +
            receivedRequests.length +
            receivedLocationRequests.length,
      );
    } on PostgrestException catch (error) {
      debugPrint('No se pudo cargar el conteo de notificaciones: $error');
    } catch (error) {
      debugPrint('No se pudo cargar el conteo de notificaciones: $error');
    }
  }

  Future<void> _loadCurrentUserPhoto() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await _client
          .from('usuarios')
          .select('user_photo')
          .eq('id', user.id)
          .maybeSingle();

      final profilePhoto = profile?['user_photo']?.toString().trim();
      final resolvedPhoto = profilePhoto?.isNotEmpty == true
          ? ExploreTrail.publicR2Url(profilePhoto)
          : user.userMetadata?['avatar_url']?.toString().trim();

      if (!mounted) return;
      setState(() => _userPhotoUrl = resolvedPhoto);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _userPhotoUrl = user.userMetadata?['avatar_url']?.toString(),
      );
    }
  }

  Widget _buildBody() {
    switch (_selectedIndex) {
      case 0:
        return ExploreContent(
          searchTerm: _exploreSearchTerm,
          showFilters: _filtersExpanded,
          onSearchChanged: (value) =>
              setState(() => _exploreSearchTerm = value),
        );
      case 1:
        return SavedContent(
          searchTerm: _savedSearchTerm,
          showFilters: _filtersExpanded,
          onSearchChanged: (value) => setState(() => _savedSearchTerm = value),
        );
      case 3:
        return AmigosContent(
          key: ValueKey('amigos-$_communityVersion'),
          searchTerm: _friendsSearchTerm,
          onSearchChanged: (value) =>
              setState(() => _friendsSearchTerm = value),
        );
      case 4:
        return const EspectadorContent();
      default:
        return ExploreContent(
          searchTerm: _exploreSearchTerm,
          onSearchChanged: (value) =>
              setState(() => _exploreSearchTerm = value),
        );
    }
  }

  Widget _buildExploreSearchField() {
    return SearchField(
      onChanged: (value) => setState(() => _exploreSearchTerm = value),
      onTap: () => setState(() => _filtersExpanded = true),
      hintText: 'Encontrar senderos',
    );
  }

  Widget _buildFriendsSearchField() {
    return SearchField(
      onChanged: (value) => setState(() => _friendsSearchTerm = value),
      hintText: 'Buscar por nombre o usuario',
    );
  }

  Widget _buildSavedSearchField() {
    return SearchField(
      onChanged: (value) => setState(() => _savedSearchTerm = value),
      onTap: () => setState(() => _filtersExpanded = true),
      hintText: 'Buscar guardados',
    );
  }

  void _selectDestination(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const GrabarPage()),
      );
      return;
    }
    setState(() {
      _selectedIndex = index;
      _filtersExpanded = false;
    });
  }

  Widget _buildHeaderSearch() {
    if (_selectedIndex == 0) {
      return _buildExploreSearchField();
    }
    if (_selectedIndex == 1) {
      return _buildSavedSearchField();
    }
    if (_selectedIndex == 3) {
      return _buildFriendsSearchField();
    }
    return const SizedBox.shrink();
  }

  Widget _buildProfileButton() {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProfilePage()),
        );
      },
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 1.5,
          ),
        ),
        child: ClipOval(
          child: DefaultUserAvatar(radius: 20, imageUrl: _userPhotoUrl),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: _selectedIndex == 4
          ? null
          : AppBar(
              toolbarHeight: 78,
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 0,
              leadingWidth: 0,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      _buildProfileButton(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: _buildHeaderSearch(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Notificaciones',
                        icon: _buildNotificationIcon(),
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NotificacionesScreen(),
                            ),
                          );
                          if (!mounted) return;
                          await _loadNotificationCount();
                          if (!mounted) return;
                          setState(() => _communityVersion++);
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
      body: _buildBody(),
      bottomNavigationBar: buildNavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        hasSharedLocation: _hasSharedLocation,
      ),
    );
  }

  Widget _buildNotificationIcon() {
    return SizedBox(
      width: 32,
      height: 32,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Align(
            alignment: Alignment.center,
            child: Icon(Icons.notifications_none_outlined),
          ),
          if (_notificationCount > 0)
            Positioned(
              top: -4,
              right: -8,
              child: Container(
                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _notificationCount > 99 ? '99+' : '$_notificationCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

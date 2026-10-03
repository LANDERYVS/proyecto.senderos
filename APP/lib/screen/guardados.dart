import 'package:flutter/material.dart';
import 'dart:io';

import '../models/explore_trail.dart';
import '../models/saved_route.dart';
import '../models/trail_waypoint.dart';
import '../services/guardado_local.dart';
import '../services/gpx_import.dart';
import '../services/logros_service.dart';
import '../services/obtener_sendero.dart';
import '../services/senderos_favoritos.dart';
import '../services/senderos_locales.dart';
import '../widgets/content_state_view.dart';
import '../widgets/edit_saved_route_dialog.dart';
import '../widgets/sendero_card.dart';
import '../widgets/filtros.dart';
import 'previsualizar_gpx.dart';

class SavedContent extends StatefulWidget {
  const SavedContent({
    super.key,
    this.searchTerm = '',
    this.onSearchChanged,
    this.showFilters = true,
    this.downloadsOnly = false,
  });

  final String searchTerm;
  final ValueChanged<String>? onSearchChanged;
  final bool showFilters;
  final bool downloadsOnly;

  @override
  State<SavedContent> createState() => _SavedContentState();
}

class _SavedContentState extends State<SavedContent> {
  final SenderosLocalesService _savedRoutesService = SenderosLocalesService();
  final SenderosFavoritosService _favoritesService = SenderosFavoritosService();
  final ObtenerSenderoService _trailService = ObtenerSenderoService();
  final RouteStorageService _routeStorageService = RouteStorageService();
  List<SavedRoute> _routes = [];
  List<ExploreTrail> _favoriteTrails = [];
  String _difficultyFilter = 'Dificultad';
  String _lengthFilter = 'Longitud';
  int _selectedTab = 0;
  int _selectedSection = 0;

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }

  Future<void> _loadRoutes() async {
    final routes = await _savedRoutesService.loadRoutes();
    var favoriteTrails = <ExploreTrail>[];
    if (!widget.downloadsOnly) {
      try {
        final favoriteIds = await _favoritesService.loadFavoriteIds();
        if (favoriteIds.isNotEmpty) {
          favoriteTrails = (await _trailService.obtenerSenderos())
              .where(
                (trail) => trail.id != null && favoriteIds.contains(trail.id),
              )
              .toList();
        }
      } on Exception catch (error) {
        debugPrint('Error al cargar senderos favoritos: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudieron sincronizar favoritos'),
            ),
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        _routes = routes;
        _favoriteTrails = favoriteTrails;
      });
    }
  }

  Future<void> _removeFavorite(ExploreTrail trail) async {
    final senderoId = trail.id;
    if (senderoId == null) return;

    try {
      await _favoritesService.removeFavorite(senderoId);
      try {
        await _savedRoutesService.removeFavoriteCache(trail);
      } on Exception catch (error) {
        debugPrint('No se pudo actualizar la copia local del favorito: $error');
      }
      if (!mounted) return;
      setState(() {
        _favoriteTrails.removeWhere((favorite) => favorite.id == senderoId);
        _routes = _routes
            .where((route) => route.favoriteSenderoId != senderoId)
            .toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"${trail.name}" quitado de favoritos')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo quitar: $error')));
    }
  }

  Future<void> _openGpx() async {
    try {
      final service = GpxImportService();
      final file = await service.pickGpxFile();
      if (file == null || !mounted) return;
      final route = await service.read(file);
      if (!mounted) return;
      final imported = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => PrevisualizarGpxScreen(file: file, route: route),
        ),
      );
      if (imported == true) await _loadRoutes();
    } on GpxImportException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el archivo GPX')),
      );
      debugPrint('Error al abrir GPX: $error');
    }
  }

  Future<void> _shareRoute(SavedRoute route) async {
    try {
      await _savedRoutesService.shareRoute(route);
    } on Exception {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo compartir el trayecto')),
      );
    }
  }

  Future<void> _openSavedRoute(SavedRoute route) async {
    try {
      final data = await GpxImportService().read(route.file);
      if (!mounted) return;
      final senderoId = (route.metadata?['senderoId'] as num?)?.toInt();
      final sourceKey = route.downloadedSourceKey;
      final offlineRegionId = sourceKey == null
          ? null
          : 'trail_${senderoId ?? sourceKey}';
      await Navigator.push<void>(
        context,
        MaterialPageRoute(
          builder: (_) => PrevisualizarGpxScreen(
            file: route.file,
            route: data,
            allowImport: false,
            offlineRegionId: offlineRegionId,
            senderoId: senderoId,
            waypoints: TrailWaypoint.fromMetadata(route.metadata?['waypoints']),
          ),
        ),
      );
    } on GpxImportException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el sendero: $error')),
      );
    }
  }

  Future<void> _deleteRoute(SavedRoute route) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Borrar sendero'),
        content: Text('¿Querés borrar "${route.name}" de este dispositivo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Borrar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final metadataFile = File(route.file.path.replaceFirst('.gpx', '.json'));
      if (await metadataFile.exists()) await metadataFile.delete();
      if (await route.file.exists()) await route.file.delete();

      final photoFolder = Directory(
        route.file.path.replaceFirst(
          RegExp(r'\.gpx$', caseSensitive: false),
          '',
        ),
      );
      if (await photoFolder.exists()) await photoFolder.delete(recursive: true);

      if (!mounted) return;
      setState(() {
        _routes.removeWhere(
          (savedRoute) => savedRoute.file.path == route.file.path,
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sendero "${route.name}" eliminado')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo borrar el sendero: $error')),
      );
    }
  }

  Future<void> _publishRoute(SavedRoute route) async {
    try {
      await _routeStorageService.publishRoute(route);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sendero "${route.name}" publicado')),
      );
      try {
        final session = await LogrosService().loadAndSync();
        try {
          if (mounted) {
            await showLogroNotifications(context, session.newlyUnlocked);
          }
        } finally {
          session.controller.dispose();
        }
      } on Object catch (error) {
        debugPrint('No se pudieron sincronizar los logros: $error');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Sendero publicado; no se pudieron actualizar los logros.',
              ),
            ),
          );
        }
      }
    } on RoutePublishException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      debugPrint('Error al publicar sendero: $error');
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error inesperado al publicar'),
        ),
      );
      debugPrint('Error inesperado al publicar sendero: $error');
    }
  }

  Widget _buildOpenGpxButton() {
    return FloatingActionButton.extended(
      onPressed: _openGpx,
      icon: const Icon(Icons.folder_open_outlined),
      label: const Text('Abrir GPX'),
      backgroundColor: const Color(0xFFBDF2C6),
      foregroundColor: const Color(0xFF1B3A2F),
    );
  }

  Widget _buildRouteTabs() {
    if (widget.downloadsOnly) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _tabButton(label: 'Mis senderos', index: 0)),
          Expanded(child: _tabButton(label: 'Senderos favoritos', index: 1)),
        ],
      ),
    );
  }

  Widget _tabButton({required String label, required int index}) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() {
        _selectedTab = index;
        _selectedSection = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? Colors.black : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.black : Colors.grey.shade600,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    if (widget.downloadsOnly) return const SizedBox.shrink();

    final labels = _selectedTab == 0
        ? const ['Creados', 'Subidos']
        : const ['Descargados', 'Favoritos'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: Row(
        children: [
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedSection = index),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: _selectedSection == index
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        width: _selectedSection == index ? 2 : 1,
                      ),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    labels[index],
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: _selectedSection == index
                          ? Theme.of(context).colorScheme.onSurface
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: _selectedSection == index
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteList() {
    final localRoutes = _filteredRoutes;
    final remoteFavorites = widget.downloadsOnly
        ? const <ExploreTrail>[]
        : _filteredFavoriteTrails;
    if (localRoutes.isEmpty && remoteFavorites.isEmpty) {
      return ContentStateView(message: _emptyRouteMessage);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: localRoutes.length + remoteFavorites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index < localRoutes.length) {
          final route = localRoutes[index];
          if (widget.downloadsOnly ||
              (_selectedTab == 1 && _selectedSection == 0)) {
            return SenderoCard(
              trail: ExploreTrail.fromDownloadedMetadata(route.metadata ?? {}),
              isFavorite: false,
              isSavingFavorite: false,
              onFavorite: null,
              topAction: _downloadedRouteMenu(route),
            );
          }
          if (_selectedTab == 0) {
            return SenderoCard(
              trail: _createdRouteTrail(route),
              isFavorite: false,
              isSavingFavorite: false,
              onFavorite: null,
              onTap: () => _openSavedRoute(route),
              topAction: _createdRouteMenu(route),
            );
          }
          final trail = _favoriteRouteTrail(route);
          return SenderoCard(
            trail: trail,
            isFavorite: true,
            isSavingFavorite: false,
            onFavorite: () => _removeFavorite(trail),
            topAction: _downloadedRouteMenu(route),
          );
        }

        final trail = remoteFavorites[index - localRoutes.length];
        return SenderoCard(
          trail: trail,
          isFavorite: true,
          isSavingFavorite: false,
          onFavorite: () => _removeFavorite(trail),
        );
      },
    );
  }

  ExploreTrail _createdRouteTrail(SavedRoute route) => ExploreTrail(
    name: route.name,
    description: route.description,
    difficulty: route.difficulty,
    sport: route.metadata?['sport']?.toString() ?? 'Sin especificar',
    distanceKm: route.distanceKm ?? 0,
    elevation: _routeElevation(route),
    author: 'Mi sendero',
    photoUrl: route.photoUrl,
    localPhotoPath: route.photos.isEmpty
        ? null
        : '${route.file.parent.path}${Platform.pathSeparator}${route.photos.first}',
  );

  ExploreTrail _favoriteRouteTrail(SavedRoute route) {
    final metadata = route.metadata ?? {};
    final senderoId = route.favoriteSenderoId;
    final photoPath = route.photos.isEmpty
        ? null
        : '${route.file.parent.path}${Platform.pathSeparator}${route.photos.first}';

    return ExploreTrail(
      id: senderoId,
      userId: metadata['userId']?.toString(),
      name: route.name,
      description: route.description,
      difficulty: route.difficulty,
      sport: metadata['sport']?.toString() ?? 'Sin especificar',
      distanceKm: route.distanceKm ?? 0,
      elevation: metadata['elevation']?.toString() ?? 'Desnivel no disponible',
      author: metadata['author']?.toString() ?? 'Sendero guardado',
      authorPhotoUrl: ExploreTrail.publicR2Url(
        metadata['authorPhotoUrl']?.toString(),
      ),
      photoUrl: ExploreTrail.publicR2Url(route.photoUrl),
      localPhotoPath: photoPath,
      gpxKey: route.favoriteSourceKey ?? route.downloadedSourceKey,
    );
  }

  String _routeElevation(SavedRoute route) {
    final gain = (route.metadata?['elevationGainMeters'] as num?)?.toDouble();
    return gain == null ? 'Desnivel no disponible' : '${gain.round()} m';
  }

  Widget _createdRouteMenu(SavedRoute route) {
    return PopupMenuButton<_CreatedRouteAction>(
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _CreatedRouteAction.edit:
            _editRoute(route);
          case _CreatedRouteAction.publish:
            _publishRoute(route);
          case _CreatedRouteAction.delete:
            _deleteRoute(route);
          case _CreatedRouteAction.share:
            _shareRoute(route);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _CreatedRouteAction.edit,
          child: Row(
            children: [
              Icon(Icons.edit_outlined),
              SizedBox(width: 8),
              Text('Editar'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _CreatedRouteAction.publish,
          child: Row(
            children: [
              Icon(Icons.cloud_upload_outlined),
              SizedBox(width: 8),
              Text('Publicar'),
            ],
          ),
        ),
        PopupMenuItem(
          value: _CreatedRouteAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Borrar', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        PopupMenuItem(
          value: _CreatedRouteAction.share,
          child: Row(
            children: [
              Icon(Icons.share_outlined),
              SizedBox(width: 8),
              Text('Compartir'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _editRoute(SavedRoute route) async {
    final editedDetails = await showEditSavedRouteDialog(context, route: route);
    if (editedDetails == null) return;
    try {
      await _savedRoutesService.updateRouteDetails(
        route: route,
        name: editedDetails.name,
        description: editedDetails.description,
        difficulty: editedDetails.difficulty,
        photo: editedDetails.photo,
      );
      await _loadRoutes();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sendero "${editedDetails.name}" actualizado')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo editar el sendero: $error')),
      );
    }
  }

  Widget _downloadedRouteMenu(SavedRoute route) {
    return PopupMenuButton<_SavedRouteAction>(
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _SavedRouteAction.delete:
            _deleteRoute(route);
          case _SavedRouteAction.share:
            _shareRoute(route);
        }
      },
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _SavedRouteAction.delete,
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red),
              SizedBox(width: 8),
              Text('Borrar', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
        PopupMenuItem(
          value: _SavedRouteAction.share,
          child: Row(
            children: [
              Icon(Icons.share_outlined),
              SizedBox(width: 8),
              Text('Compartir'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          children: [
            FilterBar(
              showSearchField: false,
              showFilters: widget.showFilters,
              onSearch: widget.onSearchChanged,
              onDifficultyChanged: (value) =>
                  setState(() => _difficultyFilter = value),
              onLengthChanged: (value) => setState(() => _lengthFilter = value),
            ),
            _buildRouteTabs(),
            _buildCategoryTabs(),
            Expanded(child: _buildRouteList()),
          ],
        ),
        Positioned(right: 20, bottom: 20, child: _buildOpenGpxButton()),
      ],
    );
  }

  List<SavedRoute> get _filteredRoutes {
    final query = widget.searchTerm.toLowerCase();
    final routesForTab = widget.downloadsOnly
        ? _routes.where((route) => route.isAvailableOffline).toList()
        : _selectedTab == 0
        ? _selectedSection == 0
              ? _routes
                    .where(
                      (route) => route.isCreatedByUser && !route.uploadedToR2,
                    )
                    .toList()
              : _routes
                    .where(
                      (route) => route.isCreatedByUser && route.uploadedToR2,
                    )
                    .toList()
        : _selectedSection == 0
        ? _routes.where((route) => route.isAvailableOffline).toList()
        : _routes
              .where(
                (route) =>
                    route.isFavorite &&
                    !_favoriteTrails.any(
                      (trail) =>
                          trail.gpxKey != null &&
                          trail.gpxKey == route.favoriteSourceKey,
                    ),
              )
              .toList();

    return routesForTab.where((route) {
      final matchesSearch =
          route.name.toLowerCase().contains(query) ||
          route.description.toLowerCase().contains(query);
      final matchesDifficulty =
          _difficultyFilter == 'Dificultad' ||
          route.difficulty == _difficultyFilter;
      final matchesLength = switch (_lengthFilter) {
        'Menos de 3 km' => route.distanceKm != null && route.distanceKm! < 3,
        '3 a 8 km' =>
          route.distanceKm != null &&
              route.distanceKm! >= 3 &&
              route.distanceKm! <= 8,
        'Más de 8 km' => route.distanceKm != null && route.distanceKm! > 8,
        _ => true,
      };
      return matchesSearch && matchesDifficulty && matchesLength;
    }).toList();
  }

  List<ExploreTrail> get _filteredFavoriteTrails {
    if (_selectedTab != 1 || _selectedSection != 1) return const [];
    final query = widget.searchTerm.toLowerCase();
    return _favoriteTrails.where((trail) {
      final matchesSearch =
          trail.name.toLowerCase().contains(query) ||
          trail.description.toLowerCase().contains(query);
      final matchesDifficulty =
          _difficultyFilter == 'Dificultad' ||
          trail.difficulty == _difficultyFilter;
      final matchesLength = switch (_lengthFilter) {
        'Menos de 3 km' => trail.distanceKm < 3,
        '3 a 8 km' => trail.distanceKm >= 3 && trail.distanceKm <= 8,
        'Más de 8 km' => trail.distanceKm > 8,
        _ => true,
      };
      return matchesSearch && matchesDifficulty && matchesLength;
    }).toList();
  }

  String get _emptyRouteMessage {
    if (widget.downloadsOnly) return 'Todavía no hay senderos descargados';
    if (_selectedTab == 0) {
      return _selectedSection == 0
          ? 'Todavía no hay senderos creados'
          : 'Todavía no hay senderos subidos';
    }
    return _selectedSection == 0
        ? 'Todavía no hay senderos descargados'
        : 'Todavía no hay senderos favoritos';
  }
}

class DownloadedTrailsScreen extends StatelessWidget {
  const DownloadedTrailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Descargados')),
      body: const SavedContent(downloadsOnly: true, showFilters: false),
    );
  }
}

enum _SavedRouteAction { delete, share }

enum _CreatedRouteAction { edit, publish, delete, share }

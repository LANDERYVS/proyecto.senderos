import 'package:flutter/material.dart';
import 'dart:io';

import '../models/explore_trail.dart';
import '../models/saved_route.dart';
import '../services/guardado_local.dart';
import '../services/gpx_import.dart';
import '../services/obtener_sendero.dart';
import '../services/senderos_favoritos.dart';
import '../services/senderos_locales.dart';
import '../widgets/content_state_view.dart';
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
      final senderoId = route.metadata?['senderoId'];
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
      onTap: () => setState(() => _selectedTab = index),
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

  Widget _buildRouteList() {
    final localRoutes = _filteredRoutes;
    final remoteFavorites = widget.downloadsOnly
        ? const <ExploreTrail>[]
        : _filteredFavoriteTrails;
    if (localRoutes.isEmpty && remoteFavorites.isEmpty) {
      return ContentStateView(
        message: widget.downloadsOnly
            ? 'Todavía no hay senderos descargados'
            : 'No hay trayectos guardados',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount: localRoutes.length + remoteFavorites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index < localRoutes.length) {
          final route = localRoutes[index];
          return _SavedRouteCard(
            route: route,
            onOpen: () => _openSavedRoute(route),
            onShare: () => _shareRoute(route),
            onPublish: () => _publishRoute(route),
            onDelete: () => _deleteRoute(route),
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
        ? _routes.where((route) => route.isCreatedByUser).toList()
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
    if (_selectedTab != 1) return const [];
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

enum _SavedRouteAction { publish, delete, share }

class _SavedRouteCard extends StatelessWidget {
  const _SavedRouteCard({
    required this.route,
    required this.onOpen,
    required this.onShare,
    required this.onPublish,
    required this.onDelete,
  });

  final SavedRoute route;
  final VoidCallback onOpen;
  final VoidCallback onShare;
  final VoidCallback onPublish;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final firstPhoto = route.photos.isNotEmpty
        ? File('${route.file.parent.path}/${route.photos.first}')
        : null;

    return Card(
      child: ListTile(
        onTap: onOpen,
        leading: firstPhoto != null && firstPhoto.existsSync()
            ? Image.file(firstPhoto, width: 52, height: 52, fit: BoxFit.cover)
            : route.photoUrl != null
            ? Image.network(
                route.photoUrl!,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) =>
                    const Icon(Icons.folder, color: Colors.amber),
              )
            : const Icon(Icons.folder, color: Colors.amber),
        title: Text(route.name),
        subtitle: Text(
          '${route.description.isNotEmpty ? '${route.description}\n' : ''}'
          '${route.difficulty} | ${route.photos.length} fotos | Archivo GPX',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: PopupMenuButton<_SavedRouteAction>(
          tooltip: 'Más opciones',
          icon: const Icon(Icons.more_vert),
          onSelected: (value) {
            switch (value) {
              case _SavedRouteAction.publish:
                onPublish();
              case _SavedRouteAction.delete:
                onDelete();
              case _SavedRouteAction.share:
                onShare();
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: _SavedRouteAction.publish,
              enabled: route.isCreatedByUser,
              child: const Row(
                children: [
                  Icon(Icons.cloud_upload_outlined),
                  SizedBox(width: 8),
                  Text('Subir sendero'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: _SavedRouteAction.delete,
              child: Row(
                children: [
                  Icon(Icons.delete_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Borrar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
            const PopupMenuItem(
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
        ),
      ),
    );
  }
}

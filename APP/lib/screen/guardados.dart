import 'package:flutter/material.dart';
import 'dart:io';

import '../models/explore_trail.dart';
import '../models/saved_route.dart';
import '../services/guardado_local.dart';
import '../services/gpx_import.dart';
import '../services/obtener_sendero.dart';
import '../services/senderos_favoritos.dart';
import '../services/senderos_locales.dart';
import '../widgets/sendero_card.dart';
import '../widgets/filtros.dart';
import 'previsualizar_gpx.dart';

class SavedContent extends StatefulWidget {
  const SavedContent({super.key});

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
  String _searchTerm = '';
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
          const SnackBar(content: Text('No se pudieron sincronizar favoritos')),
        );
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _openGpx,
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('Abrir archivo GPX'),
        ),
      ),
    );
  }

  Widget _buildRouteTabs() {
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
    final remoteFavorites = _filteredFavoriteTrails;
    if (localRoutes.isEmpty && remoteFavorites.isEmpty) {
      return const Center(child: Text('No hay trayectos guardados'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: localRoutes.length + remoteFavorites.length,
      itemBuilder: (context, index) {
        if (index < localRoutes.length) {
          final route = localRoutes[index];
          return _SavedRouteCard(
            route: route,
            onShare: () => _shareRoute(route),
            onPublish: () => _publishRoute(route),
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
    return Column(
      children: [
        _buildOpenGpxButton(),
        FilterBar(
          onSearch: (value) => setState(() => _searchTerm = value),
          onDifficultyChanged: (value) =>
              setState(() => _difficultyFilter = value),
          onLengthChanged: (value) => setState(() => _lengthFilter = value),
        ),
        _buildRouteTabs(),
        Expanded(child: _buildRouteList()),
      ],
    );
  }

  List<SavedRoute> get _filteredRoutes {
    final query = _searchTerm.toLowerCase();
    final routesForTab = _selectedTab == 0
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
    final query = _searchTerm.toLowerCase();
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

class _SavedRouteCard extends StatelessWidget {
  const _SavedRouteCard({
    required this.route,
    required this.onShare,
    required this.onPublish,
  });

  final SavedRoute route;
  final VoidCallback onShare;
  final VoidCallback onPublish;

  @override
  Widget build(BuildContext context) {
    final firstPhoto = route.photos.isNotEmpty
        ? File('${route.file.parent.path}/${route.photos.first}')
        : null;

    return Card(
      child: ListTile(
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
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Publicar sendero',
              icon: const Icon(Icons.cloud_upload_outlined),
              onPressed: route.isCreatedByUser ? onPublish : null,
            ),
            IconButton(
              tooltip: 'Compartir trayecto',
              icon: const Icon(Icons.share_outlined),
              onPressed: onShare,
            ),
          ],
        ),
        onTap: onShare,
      ),
    );
  }
}

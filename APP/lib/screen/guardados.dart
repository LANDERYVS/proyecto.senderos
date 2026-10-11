// Aquí se implementa una pantalla de la app.

import 'package:flutter/material.dart';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/modelo_sendero.dart';
import '../models/modelo_ruta.dart';
import '../models/waypoints_sendero.dart';
import '../services/guardado_local.dart';
import '../services/gpx_import.dart';
import '../services/logros_service.dart';
import '../services/obtener_sendero.dart';
import '../services/senderos_favoritos.dart';
import '../services/senderos_locales.dart';
import '../widgets/content_state_view.dart';
import '../widgets/dialogo_editar_ruta.dart';
import '../widgets/no_transition_page_route.dart';
import '../widgets/sendero_card.dart';
import '../widgets/filtros.dart';
import 'previsualizar_gpx.dart';
// Muestra las rutas creadas, publicadas, descargadas y guardadas como favoritas.

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
// Mantiene las rutas y filtros que se muestran en la pantalla de guardados.

class _SavedContentState extends State<SavedContent> {
  final SenderosLocalesService _savedRoutesService = SenderosLocalesService();
  final SenderosFavoritosService _favoritesService = SenderosFavoritosService();
  final ObtenerSenderoService _trailService = ObtenerSenderoService();
  final RouteStorageService _routeStorageService = RouteStorageService();
  List<SavedRoute> _routes = [];
  List<ExploreTrail> _uploadedTrails = [];
  List<ExploreTrail> _favoriteTrails = [];
  String _difficultyFilter = 'Dificultad';
  String _lengthFilter = 'Longitud';
  String _sportFilter = 'Deporte';
  int _selectedTab = 0;
  int _selectedSection = 0;
  // Al abrir esta pantalla, se cargan los datos iniciales y se preparan las suscripciones necesarias.

  @override
  void initState() {
    super.initState();
    _loadRoutes();
  }
  // Carga las rutas del dispositivo y, si hay sesión iniciada, también las publicadas y favoritas.

  Future<void> _loadRoutes() async {
    final routes = await _savedRoutesService.loadRoutes();
    var uploadedTrails = <ExploreTrail>[];
    var favoriteTrails = <ExploreTrail>[];
    if (!widget.downloadsOnly) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId != null) {
        try {
          final remoteTrails = await _trailService.obtenerSenderos();
          uploadedTrails = remoteTrails
              .where((trail) => trail.userId == userId)
              .toList();

          try {
            final favoriteIds = await _favoritesService.loadFavoriteIds();
            favoriteTrails = remoteTrails
                .where(
                  (trail) => trail.id != null && favoriteIds.contains(trail.id),
                )
                .toList();
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
        } on Exception catch (error) {
          debugPrint('Error al cargar senderos remotos: $error');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No se pudieron cargar los senderos publicados'),
              ),
            );
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _routes = routes;
        _uploadedTrails = uploadedTrails;
        _favoriteTrails = favoriteTrails;
      });
    }
  }
  // Quita el elemento seleccionado de la lista o de los datos guardados.

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
  // Abre el contenido seleccionado para que el usuario pueda consultarlo.

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
      if (imported == true) {
        setState(() {
          _selectedTab = 0;
          _selectedSection = 0;
        });
        await _loadRoutes();
      }
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
  // Abre el contenido seleccionado para que el usuario pueda consultarlo.

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
        NoTransitionPageRoute(
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
  // Elimina el elemento seleccionado y actualiza la información guardada.

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

  // Después de publicar, vuelve a cargar la lista. Si falla, avisa que la publicación pudo completarse igualmente.
  Future<void> _refreshRoutesAfterPublish() async {
    try {
      await _loadRoutes();
    } on Exception catch (error) {
      // El fallo de actualización no deshace la publicación; se informa para que el usuario sepa que la lista está desactualizada.
      debugPrint('No se pudo actualizar la lista tras publicar: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'El sendero se publicó, pero la lista no pudo actualizarse.',
            ),
          ),
        );
      }
    }
  }

  // Sube la ruta, actualiza la lista y comprueba si publicar desbloqueó algún logro.
  Future<void> _publishRoute(SavedRoute route) async {
    try {
      // Envía el archivo y sus datos al servicio de almacenamiento/publicación.
      await _routeStorageService.publishRoute(route);
      if (!mounted) return;
      // Refresca la pantalla para reflejar que la ruta ya fue publicada.
      await _refreshRoutesAfterPublish();
      if (!mounted) return;
      // Confirma al usuario que la publicación terminó correctamente.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sendero "${route.name}" publicado')),
      );
      try {
        // La publicación puede sumar progreso y desbloquear logros.
        final session = await LogrosService().loadAndSync();
        try {
          // Muestra los logros nuevos solo si esta pantalla sigue activa.
          if (mounted) {
            await showLogroNotifications(context, session.newlyUnlocked);
          }
        } finally {
          // Libera los recursos temporales usados para revisar los logros.
          session.controller.dispose();
        }
      } on Object catch (error) {
        // Un error de logros no invalida la publicación, así que solo se informa por separado.
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
      // Error esperado al publicar, por ejemplo por permisos o por un problema de almacenamiento.
      if (!mounted) return;
      await _refreshRoutesAfterPublish();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
      debugPrint('Error al publicar sendero: $error');
    } on Exception catch (error) {
      // Captura otros fallos para avisar sin cerrar la pantalla.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ocurrió un error inesperado al publicar'),
        ),
      );
      debugPrint('Error inesperado al publicar sendero: $error');
    }
  }

  // Botón flotante que permite elegir e importar un archivo GPX.
  Widget _buildOpenGpxButton() {
    return FloatingActionButton.extended(
      onPressed: _openGpx,
      icon: const Icon(Icons.folder_open_outlined),
      label: const Text('Importar sendero'),
      backgroundColor: const Color(0xFFBDF2C6),
      foregroundColor: const Color(0xFF1B3A2F),
    );
  }

  // Muestra las dos secciones principales, salvo cuando esta vista se limita a descargas.
  Widget _buildRouteTabs() {
    if (widget.downloadsOnly) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _tabButton(label: 'Mis senderos', index: 0)),
          Expanded(child: _tabButton(label: 'Otros', index: 1)),
        ],
      ),
    );
  }

  // Dibuja una pestaña y cambia la sección activa cuando el usuario la toca.
  Widget _tabButton({required String label, required int index}) {
    final isSelected = _selectedTab == index;
    final colors = Theme.of(context).colorScheme;
    return GestureDetector(
      // Al cambiar de pestaña, vuelve a la primera categoría de esa sección.
      onTap: () => setState(() {
        _selectedTab = index;
        _selectedSection = 0;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colors.primary : colors.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: isSelected ? colors.onSurface : colors.onSurfaceVariant,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // Según la pestaña principal, muestra sus dos categorías correspondientes.
  Widget _buildCategoryTabs() {
    if (widget.downloadsOnly) return const SizedBox.shrink();

    final labels = _selectedTab == 0
        ? const ['Creados', 'Subidos']
        : const ['Descargados', 'Favoritos'];
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
      child: Row(
        children: [
          // Cada etiqueta es una categoría; el borde indica cuál está seleccionada.
          for (var index = 0; index < labels.length; index++)
            Expanded(
              child: GestureDetector(
                // Al tocar una categoría, actualiza qué grupo de rutas se muestra.
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

  // Combina rutas locales, publicadas y favoritas en una sola lista de tarjetas.
  Widget _buildRouteList() {
    // Obtiene las listas ya filtradas según la pestaña, búsqueda y filtros actuales.
    final localRoutes = _filteredRoutes;
    final remoteUploaded = _filteredUploadedTrails;
    final remoteFavorites = widget.downloadsOnly
        ? const <ExploreTrail>[]
        : _filteredFavoriteTrails;
    if (localRoutes.isEmpty &&
        remoteUploaded.isEmpty &&
        remoteFavorites.isEmpty) {
      // Si ningún grupo tiene rutas, muestra el mensaje adecuado para la sección elegida.
      return ContentStateView(message: _emptyRouteMessage);
    }

    // Construye una tarjeta por cada ruta, usando el tipo de tarjeta adecuado para cada origen.
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
      itemCount:
          localRoutes.length + remoteUploaded.length + remoteFavorites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        if (index < localRoutes.length) {
          final route = localRoutes[index];
          // En la vista de descargas, las rutas locales se muestran como rutas descargadas.
          if (widget.downloadsOnly ||
              (_selectedTab == 1 && _selectedSection == 0)) {
            return SenderoCard(
              trail: ExploreTrail.fromDownloadedMetadata(route.metadata ?? {}),
              topAction: _downloadedRouteMenu(route),
            );
          }
          // En "Creados", muestra las rutas creadas en este dispositivo con editar/publicar/borrar.
          if (_selectedTab == 0) {
            return SenderoCard(
              trail: _createdRouteTrail(route),
              onTap: () => _openSavedRoute(route),
              topAction: _createdRouteMenu(route),
            );
          }
          // En "Favoritos", permite quitar la ruta de favoritos y administrar su copia local.
          final trail = _favoriteRouteTrail(route);
          return SenderoCard(
            trail: trail,
            topAction: _downloadedRouteMenu(route),
          );
        }

        // Una vez terminadas las rutas locales, calcula el índice dentro de las publicadas.
        final uploadedIndex = index - localRoutes.length;
        if (uploadedIndex < remoteUploaded.length) {
          // Las publicadas se muestran directamente con sus datos remotos.
          return SenderoCard(trail: remoteUploaded[uploadedIndex]);
        }

        // Los elementos restantes son favoritos cargados desde el servidor.
        final trail = remoteFavorites[uploadedIndex - remoteUploaded.length];
        return SenderoCard(trail: trail, topAction: _favoriteTrailMenu(trail));
      },
    );
  }

  Widget _favoriteTrailMenu(ExploreTrail trail) {
    return PopupMenuButton<bool>(
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert),
      onSelected: (_) => _removeFavorite(trail),
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: true,
          child: Row(
            children: [
              Icon(Icons.favorite_border, color: Colors.red),
              SizedBox(width: 8),
              Text('Quitar de favoritos'),
            ],
          ),
        ),
      ],
    );
  }

  // Adapta una ruta creada localmente al modelo que esperan las tarjetas de senderos.
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

  // Convierte una ruta favorita guardada localmente al modelo común de senderos.
  ExploreTrail _favoriteRouteTrail(SavedRoute route) {
    // Recupera datos adicionales y prepara la ruta de su primera foto local, si existe.
    final metadata = route.metadata ?? {};
    final senderoId = route.favoriteSenderoId;
    final photoPath = route.photos.isEmpty
        ? null
        : '${route.file.parent.path}${Platform.pathSeparator}${route.photos.first}';

    // Reúne datos locales y del servidor para que la tarjeta muestre autor, foto y GPX.
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

  // Convierte el desnivel guardado en metadata a un texto para mostrar en pantalla.
  String _routeElevation(SavedRoute route) {
    final gain = (route.metadata?['elevationGainMeters'] as num?)?.toDouble();
    return gain == null ? 'Desnivel no disponible' : '${gain.round()} m';
  }

  // Menú de acciones para una ruta creada por el usuario.
  Widget _createdRouteMenu(SavedRoute route) {
    return PopupMenuButton<_CreatedRouteAction>(
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert),
      // Ejecuta la acción elegida en el menú.
      onSelected: (action) {
        switch (action) {
          case _CreatedRouteAction.edit:
            _editRoute(route);
          case _CreatedRouteAction.publish:
            _publishRoute(route);
          case _CreatedRouteAction.delete:
            _deleteRoute(route);
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
  // Muestra las opciones disponibles para una ruta descargada.

  Widget _downloadedRouteMenu(SavedRoute route) {
    return PopupMenuButton<_SavedRouteAction>(
      tooltip: 'Más opciones',
      icon: const Icon(Icons.more_vert),
      onSelected: (action) {
        switch (action) {
          case _SavedRouteAction.delete:
            _deleteRoute(route);
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
      ],
    );
  }
  // Construye la interfaz de esta pantalla con los datos y filtros actuales.

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
              onSportChanged: (value) => setState(() => _sportFilter = value),
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

  bool _matchesSearch(String candidate, String query) {
    final value = candidate.toLowerCase();
    return value.contains(query);
  }

  bool _matchesLength(double? distance) {
    if (distance == null) return false;
    return switch (_lengthFilter) {
      'Menos de 3 km' => distance < 3,
      '3 a 8 km' => distance >= 3 && distance <= 8,
      'Más de 8 km' => distance > 8,
      _ => true,
    };
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
              : const <SavedRoute>[]
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
          _matchesSearch(route.name, query) ||
          _matchesSearch(route.description, query);
      final matchesDifficulty =
          _difficultyFilter == 'Dificultad' ||
          route.difficulty == _difficultyFilter;
      final matchesSport =
          _sportFilter == 'Deporte' || route.sport == _sportFilter;
      return matchesSearch &&
          matchesDifficulty &&
          matchesSport &&
          _matchesLength(route.distanceKm);
    }).toList();
  }

  List<ExploreTrail> get _filteredUploadedTrails {
    if (widget.downloadsOnly || _selectedTab != 0 || _selectedSection != 1) {
      return const [];
    }

    final query = widget.searchTerm.toLowerCase();
    return _uploadedTrails.where((trail) {
      final matchesSearch =
          _matchesSearch(trail.name, query) ||
          _matchesSearch(trail.description, query);
      final matchesDifficulty =
          _difficultyFilter == 'Dificultad' ||
          trail.difficulty == _difficultyFilter;
      final matchesSport =
          _sportFilter == 'Deporte' || trail.sport == _sportFilter;
      return matchesSearch &&
          matchesDifficulty &&
          matchesSport &&
          _matchesLength(trail.distanceKm);
    }).toList();
  }

  List<ExploreTrail> get _filteredFavoriteTrails {
    if (_selectedTab != 1 || _selectedSection != 1) return const [];
    final query = widget.searchTerm.toLowerCase();
    return _favoriteTrails.where((trail) {
      final matchesSearch =
          _matchesSearch(trail.name, query) ||
          _matchesSearch(trail.description, query);
      final matchesDifficulty =
          _difficultyFilter == 'Dificultad' ||
          trail.difficulty == _difficultyFilter;
      final matchesSport =
          _sportFilter == 'Deporte' || trail.sport == _sportFilter;
      return matchesSearch &&
          matchesDifficulty &&
          matchesSport &&
          _matchesLength(trail.distanceKm);
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
// Esta enumeración lista las opciones disponibles para esta función.

enum _SavedRouteAction { delete }
// Esta enumeración lista las opciones disponibles para esta función.

enum _CreatedRouteAction { edit, publish, delete }

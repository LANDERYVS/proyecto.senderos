import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:xml/xml.dart';

import '../models/clima_sendero.dart';
import '../models/explore_trail.dart';
import '../services/offline_tile_service.dart';
import '../services/servicio_clima_sendero.dart';
import '../services/senderos_locales.dart';
import '../utils/route_calculator.dart';
import '../widgets/clima_sendero_card.dart';
import '../widgets/route_polyline_map.dart';
import 'seguir_sendero.dart';

class DetalleSenderoScreen extends StatefulWidget {
  const DetalleSenderoScreen({super.key, required this.trail});

  final ExploreTrail trail;

  @override
  State<DetalleSenderoScreen> createState() => _DetalleSenderoScreenState();
}

class _DetalleSenderoScreenState extends State<DetalleSenderoScreen> {
  List<LatLng> _routePoints = const [];
  bool _isLoadingRoute = true;
  String? _routeError;
  bool _isLoadingWeather = false;
  ClimaSendero? _weather;
  final _weatherService = ServicioClimaSendero();
  final _offlineTileService = OfflineTileService();
  final _savedRoutesService = SenderosLocalesService();
  Timer? _weatherRefreshTimer;
  TileLayer? _offlineTileLayer;
  bool _isDownloadingOffline = false;
  bool _isOfflineReady = false;
  double _downloadProgress = 0;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _weatherRefreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (mounted && _routePoints.isNotEmpty && !_isLoadingWeather) {
        _loadTrailWeather(RouteCalculator.centerOfPoints(_routePoints)!);
      }
    });
  }

  @override
  void dispose() {
    _weatherRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final url = widget.trail.gpxUrl;
    if (url == null) {
      setState(() => _isLoadingRoute = false);
      return;
    }

    try {
      final localGpx = await _savedRoutesService.findDownloadedTrail(
        widget.trail,
      );
      String gpxContent;
      if (localGpx != null) {
        gpxContent = await localGpx.readAsString();
      } else {
        final client = HttpClient();
        try {
          final request = await client.getUrl(Uri.parse(url));
          final response = await request.close();
          if (response.statusCode != HttpStatus.ok) {
            throw HttpException(
              'HTTP ${response.statusCode}',
              uri: Uri.parse(url),
            );
          }
          gpxContent = await response.transform(const Utf8Decoder()).join();
        } finally {
          client.close(force: true);
        }
      }
      final document = XmlDocument.parse(gpxContent);
      final points = document
          .findAllElements('trkpt')
          .map((element) {
            final latitude = double.tryParse(element.getAttribute('lat') ?? '');
            final longitude = double.tryParse(
              element.getAttribute('lon') ?? '',
            );
            return latitude != null && longitude != null
                ? LatLng(latitude, longitude)
                : null;
          })
          .whereType<LatLng>()
          .toList();
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _isLoadingRoute = false;
      });
      await _loadOfflineMap(localGpx != null);
      if (points.isNotEmpty) {
        _loadTrailWeather(RouteCalculator.centerOfPoints(points)!);
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingRoute = false;
        _routeError = error.toString();
      });
    }
  }

  String get _offlineRegionId =>
      'trail_${widget.trail.id ?? widget.trail.gpxKey}';

  Future<void> _loadOfflineMap(bool hasLocalGpx) async {
    final hasTiles = await _offlineTileService.hasDownloadedTiles(
      regionId: _offlineRegionId,
    );
    if (!hasTiles || !mounted) return;
    final layer = await _offlineTileService.offlineTileLayer(
      regionId: _offlineRegionId,
    );
    if (!mounted) return;
    setState(() {
      _offlineTileLayer = layer;
      _isOfflineReady = hasLocalGpx;
    });
  }

  LatLngBounds _boundsForRoute(List<LatLng> points) {
    final latitudes = points.map((point) => point.latitude);
    final longitudes = points.map((point) => point.longitude);
    const padding = 0.005;
    return LatLngBounds(
      LatLng(
        latitudes.reduce((first, second) => first < second ? first : second) -
            padding,
        longitudes.reduce((first, second) => first < second ? first : second) -
            padding,
      ),
      LatLng(
        latitudes.reduce((first, second) => first > second ? first : second) +
            padding,
        longitudes.reduce((first, second) => first > second ? first : second) +
            padding,
      ),
    );
  }

  Future<void> _downloadOfflineResources() async {
    if (_isDownloadingOffline || _routePoints.length < 2) return;
    setState(() {
      _isDownloadingOffline = true;
      _downloadProgress = 0;
    });

    try {
      await _savedRoutesService.downloadTrailForOffline(widget.trail);
      await _offlineTileService.downloadRegion(
        bounds: _boundsForRoute(_routePoints),
        regionId: _offlineRegionId,
        minZoom: 12,
        maxZoom: 16,
        onProgress: (completed, total) {
          if (mounted) {
            setState(() => _downloadProgress = completed / total);
          }
        },
      );
      await _savedRoutesService.markTrailAvailableOffline(widget.trail);
      final layer = await _offlineTileService.offlineTileLayer(
        regionId: _offlineRegionId,
      );
      if (!mounted) return;
      setState(() {
        _offlineTileLayer = layer;
        _isOfflineReady = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('GPX y mapa guardados sin conexión')),
      );
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo completar la descarga: $error')),
      );
    } finally {
      if (mounted) setState(() => _isDownloadingOffline = false);
    }
  }

  Future<void> _loadTrailWeather(LatLng location) async {
    setState(() {
      _isLoadingWeather = true;
    });

    try {
      final weather = await _weatherService.obtenerClima(location);
      if (!mounted) return;
      setState(() {
        _weather = weather;
        _isLoadingWeather = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isLoadingWeather = false;
      });
    }
  }

  void _openTrailTracking() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeguirSenderoPage(
          routePoints: _routePoints,
          routeName: widget.trail.name,
          senderoId: widget.trail.id,
        ),
      ),
    );
  }

  Future<void> _deleteOwnTrail() async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final trailId = widget.trail.id;

    if (currentUserId == null || trailId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes iniciar sesión para eliminar senderos.'),
        ),
      );
      return;
    }

    if (widget.trail.userId != currentUserId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puedes eliminar tus senderos.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar sendero'),
        content: Text(
          '¿Querés eliminar "${widget.trail.name}"? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await Supabase.instance.client
          .from('senderos_favoritos')
          .delete()
          .eq('sendero_id', trailId);

      await Supabase.instance.client
          .from('senderos')
          .delete()
          .eq('id', trailId)
          .eq('user_id', currentUserId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se eliminó "${widget.trail.name}"')),
      );
      Navigator.pop(context, true);
    } on PostgrestException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        '42501' =>
          'No se pudo eliminar porque la base de datos bloquea esta acción. Debés habilitar DELETE en la política RLS de la tabla senderos para tu usuario.',
        _ => 'No se pudo eliminar el sendero: ${error.message}',
      };
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Widget _buildTrailHero() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        height: 250,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            widget.trail.photoUrl == null
                ? Image.asset('assets/arbol.jpg', fit: BoxFit.cover)
                : Image.network(
                    widget.trail.photoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, error, stackTrace) =>
                        Image.asset('assets/arbol.jpg', fit: BoxFit.cover),
                  ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.68),
                  ],
                  stops: const [0.28, 1],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  child: Text(
                    widget.trail.difficulty,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.trail.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      shadows: const [
                        Shadow(color: Colors.black54, blurRadius: 8),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 12,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        backgroundImage: widget.trail.authorPhotoUrl != null
                            ? NetworkImage(widget.trail.authorPhotoUrl!)
                            : const AssetImage('assets/usuario.png')
                                  as ImageProvider,
                        onBackgroundImageError: (_, _) {},
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Publicado por: ${widget.trail.author}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.white,
                                shadows: const [
                                  Shadow(color: Colors.black54, blurRadius: 6),
                                ],
                              ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowTrailButton() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _openTrailTracking,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: const Icon(Icons.directions_walk_outlined),
            label: const Text('Seguir sendero'),
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteTrailButton() {
    final isOwner =
        widget.trail.userId == Supabase.instance.client.auth.currentUser?.id;

    if (!isOwner) return const SizedBox.shrink();

    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _deleteOwnTrail,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
          ),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Eliminar sendero'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Información del sendero')),
      bottomNavigationBar: _buildFollowTrailButton(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTrailHero(),
            const SizedBox(height: 16),
            _TrailInfo(
              difficulty: widget.trail.difficulty,
              distance: '${widget.trail.distanceKm.toStringAsFixed(1)} km',
              elevation: widget.trail.elevation,
            ),
            const SizedBox(height: 24),
            Text(
              'Descripción',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.trail.description.isEmpty
                  ? 'Este sendero no tiene una descripción.'
                  : widget.trail.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Trayecto',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            RoutePolylineMap(
              points: _routePoints,
              tileLayer: _offlineTileLayer,
              isLoading: _isLoadingRoute,
              hasError: _routeError != null,
            ),
            const SizedBox(height: 12),
            if (_isDownloadingOffline) ...[
              LinearProgressIndicator(value: _downloadProgress),
              const SizedBox(height: 6),
            ],
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    _isDownloadingOffline ||
                        _isOfflineReady ||
                        _isLoadingRoute ||
                        _routePoints.length < 2 ||
                        widget.trail.gpxUrl == null
                    ? null
                    : _downloadOfflineResources,
                icon: Icon(
                  _isOfflineReady
                      ? Icons.offline_pin
                      : Icons.download_for_offline_outlined,
                ),
                label: Text(
                  _isDownloadingOffline
                      ? 'Descargando ${(_downloadProgress * 100).round()}%'
                      : _isOfflineReady
                      ? 'Disponible sin conexión'
                      : widget.trail.gpxUrl == null
                      ? 'GPX no disponible'
                      : _routePoints.length < 2 && !_isLoadingRoute
                      ? 'Ruta no disponible'
                      : 'Descargar GPX y mapa',
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Clima del sendero',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ClimaSenderoCard(
              isLoading: _isLoadingRoute || _isLoadingWeather,
              hasRoute: _routePoints.isNotEmpty,
              weather: _weather,
              location: RouteCalculator.centerOfPoints(_routePoints),
              onRefresh: _routePoints.isEmpty
                  ? () {}
                  : () => _loadTrailWeather(
                      RouteCalculator.centerOfPoints(_routePoints)!,
                    ),
            ),
            const SizedBox(height: 28),
            _buildDeleteTrailButton(),
          ],
        ),
      ),
    );
  }
}

class _TrailInfo extends StatelessWidget {
  const _TrailInfo({
    required this.difficulty,
    required this.distance,
    required this.elevation,
  });

  final String difficulty;
  final String distance;
  final String elevation;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: _InfoItem(
              icon: Icons.terrain,
              label: 'Dificultad',
              value: difficulty,
            ),
          ),
          Container(width: 1, height: 40, color: colors.outlineVariant),
          Expanded(
            child: _InfoItem(
              icon: Icons.straighten,
              label: 'Distancia',
              value: distance,
            ),
          ),
          Container(width: 1, height: 40, color: colors.outlineVariant),
          Expanded(
            child: _InfoItem(
              icon: Icons.height,
              label: 'Desnivel',
              value: elevation,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

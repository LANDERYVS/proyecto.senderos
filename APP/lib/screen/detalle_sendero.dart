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
import '../services/servicio_clima_sendero.dart';
import '../widgets/clima_sendero_card.dart';
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
  Timer? _weatherRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _weatherRefreshTimer = Timer.periodic(const Duration(minutes: 30), (_) {
      if (mounted && _routePoints.isNotEmpty && !_isLoadingWeather) {
        _loadTrailWeather(_centerOf(_routePoints));
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
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final document = XmlDocument.parse(
        await response.transform(const Utf8Decoder()).join(),
      );
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
      client.close();
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _isLoadingRoute = false;
      });
      if (points.isNotEmpty) {
        _loadTrailWeather(_centerOf(points));
      }
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingRoute = false;
        _routeError = error.toString();
      });
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
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 220,
        width: double.infinity,
        color: const Color(0xffeaf5df),
        child: widget.trail.photoUrl == null
            ? Image.asset('assets/arbol.jpg', fit: BoxFit.contain)
            : Image.network(
                widget.trail.photoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stackTrace) =>
                    Image.asset('assets/arbol.jpg', fit: BoxFit.contain),
              ),
      ),
    );
  }

  Widget _buildFollowTrailButton() {
    return SafeArea(
      top: false,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _openTrailTracking,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: const Icon(Icons.directions_walk_outlined),
          label: const Text('Seguir sendero'),
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
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Información del sendero')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTrailHero(),
            const SizedBox(height: 20),
            Text(
              widget.trail.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: colors.surfaceContainerHighest,
                  backgroundImage: widget.trail.authorPhotoUrl != null
                      ? NetworkImage(widget.trail.authorPhotoUrl!)
                      : const AssetImage('assets/usuario.png') as ImageProvider,
                  onBackgroundImageError: (_, __) {},
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Publicado por: ${widget.trail.author}',
                    style: TextStyle(color: colors.onSurfaceVariant),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _TrailInfo(
              difficulty: widget.trail.difficulty,
              distance: '${widget.trail.distanceKm.toStringAsFixed(1)} km',
              elevation: widget.trail.elevation,
            ),
            const SizedBox(height: 24),
            Text(
              'Trayecto',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            _RouteMap(
              points: _routePoints,
              isLoading: _isLoadingRoute,
              hasError: _routeError != null,
            ),
            const SizedBox(height: 20),
            Text(
              'Clima del sendero',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            ClimaSenderoCard(
              isLoading: _isLoadingRoute || _isLoadingWeather,
              hasRoute: _routePoints.isNotEmpty,
              weather: _weather,
              location: _routePoints.isEmpty ? null : _centerOf(_routePoints),
              onRefresh: _routePoints.isEmpty
                  ? () {}
                  : () => _loadTrailWeather(_centerOf(_routePoints)),
            ),
            const SizedBox(height: 24),
            Text(
              'Descripción',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.trail.description.isEmpty
                  ? 'Este sendero no tiene una descripción.'
                  : widget.trail.description,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 28),
            _buildDeleteTrailButton(),
            const SizedBox(height: 12),
            _buildFollowTrailButton(),
          ],
        ),
      ),
    );
  }

  LatLng _centerOf(List<LatLng> points) {
    final latitude = points.fold<double>(
      0,
      (sum, point) => sum + point.latitude,
    );
    final longitude = points.fold<double>(
      0,
      (sum, point) => sum + point.longitude,
    );
    return LatLng(latitude / points.length, longitude / points.length);
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({
    required this.points,
    required this.isLoading,
    required this.hasError,
  });

  final List<LatLng> points;
  final bool isLoading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        height: 180,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (points.length < 2 || hasError) {
      return Container(
        height: 180,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text('El trayecto no está disponible'),
      );
    }

    final center = _centerOf(points);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 180,
        child: FlutterMap(
          options: MapOptions(initialCenter: center, initialZoom: 14),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'proyecto.senderos',
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: const Color(0xff4f8f3a),
                  strokeWidth: 5,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LatLng _centerOf(List<LatLng> points) {
    final latitude = points.fold<double>(
      0,
      (sum, point) => sum + point.latitude,
    );
    final longitude = points.fold<double>(
      0,
      (sum, point) => sum + point.longitude,
    );
    return LatLng(latitude / points.length, longitude / points.length);
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
    return Row(
      children: [
        Expanded(
          child: _InfoItem(
            icon: Icons.terrain,
            label: 'Dificultad',
            value: difficulty,
          ),
        ),
        Expanded(
          child: _InfoItem(
            icon: Icons.straighten,
            label: 'Distancia',
            value: distance,
          ),
        ),
        Expanded(
          child: _InfoItem(
            icon: Icons.height,
            label: 'Desnivel',
            value: elevation,
          ),
        ),
      ],
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
        Icon(icon, size: 22),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

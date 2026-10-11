// Aquí se implementa una pantalla de la app.


import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../models/waypoints_sendero.dart';
import '../services/gpx_import.dart';
import '../services/guardado_local.dart';
import '../services/offline_tile_service.dart';
import '../widgets/mapa_trazado_sendero.dart';
import '../widgets/dialogo_guardado.dart';
import 'seguir_sendero_descargado.dart';
// La clase PrevisualizarGpxScreen reúne los datos y las acciones de esta parte de la app.

class PrevisualizarGpxScreen extends StatefulWidget {
  const PrevisualizarGpxScreen({
    super.key,
    required this.file,
    required this.route,
    this.allowImport = true,
    this.offlineRegionId,
    this.senderoId,
    this.waypoints = const [],
  });

  final File file;
  final GpxRouteData route;
  final bool allowImport;
  final String? offlineRegionId;
  final int? senderoId;
  final List<TrailWaypoint> waypoints;

  @override
  State<PrevisualizarGpxScreen> createState() => _PrevisualizarGpxScreenState();
}
// La clase _PrevisualizarGpxScreenState reúne los datos y las acciones de esta parte de la app.

class _PrevisualizarGpxScreenState extends State<PrevisualizarGpxScreen> {
  bool _isImporting = false;
  TileLayer? _offlineTileLayer;
// Al abrir esta pantalla, se cargan los datos iniciales y se preparan las suscripciones necesarias.

  @override
  void initState() {
    super.initState();
    _loadOfflineMap();
  }
// Carga los datos necesarios para mostrar la información más reciente.

  Future<void> _loadOfflineMap() async {
    final regionId = widget.offlineRegionId;
    if (regionId == null) return;
    final tileService = OfflineTileService();
    final layer = await tileService.offlineTileLayerIfAvailable(
      regionId: regionId,
    );
    if (mounted && layer != null) setState(() => _offlineTileLayer = layer);
  }

  Future<void> _importRoute() async {
    final details = await showSaveRouteDialog(
      context,
      duration: 'No disponible',
      distanceKm: widget.route.distanceKm,
      elevationGainMeters: widget.route.elevationGainMeters,
      initialName: widget.route.name,
    );
    if (details == null || !mounted) return;

    setState(() => _isImporting = true);
    try {
      await RouteStorageService().saveRoute(
        points: widget.route.points,
        routeName: details.name,
        description: details.description,
        sport: details.sport,
        difficulty: details.difficulty,
        photos: details.photos,
        distanceKm: widget.route.distanceKm,
        elevationGainMeters: widget.route.elevationGainMeters,
        elevationLossMeters: widget.route.elevationLossMeters,
        waypoints: [for (final waypoint in widget.waypoints) waypoint.toMap()],
        sourceGpx: widget.file,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sendero importado en Mis senderos')),
      );
      Navigator.pop(context, true);
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() => _isImporting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo importar: $error')));
    }
  }

  void _followRoute() {
    final offlineRegionId = widget.offlineRegionId;
    if (offlineRegionId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SeguirSenderoDescargadoPage(
          routePoints: widget.route.points,
          routeName: widget.route.name,
          offlineRegionId: offlineRegionId,
          senderoId: widget.senderoId,
          waypoints: widget.waypoints,
        ),
      ),
    );
  }
// Construye la interfaz de esta pantalla con los datos y filtros actuales.

  @override
  Widget build(BuildContext context) {
    final points = widget.route.points;
    return Scaffold(
      appBar: AppBar(title: const Text('Previsualizar GPX')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.route.name,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text('${points.length} puntos de ruta'),
            const SizedBox(height: 16),
            Expanded(
              child: RoutePolylineMap(
                points: points,
                waypoints: widget.waypoints,
                height: null,
                tileLayer: _offlineTileLayer,
              ),
            ),
            if (widget.allowImport) ...[
              const SizedBox(height: 16),
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _isImporting ? null : _importRoute,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.download_outlined),
                    label: Text(
                      _isImporting ? 'Importando...' : 'Importar sendero',
                    ),
                  ),
                ),
              ),
            ],
            if (!widget.allowImport && widget.offlineRegionId != null) ...[
              const SizedBox(height: 16),
              SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _followRoute,
                    icon: const Icon(Icons.directions_walk_outlined),
                    label: const Text('Seguir sendero'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

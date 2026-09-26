import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/gpx_import.dart';

class PrevisualizarGpxScreen extends StatefulWidget {
  const PrevisualizarGpxScreen({
    super.key,
    required this.file,
    required this.route,
  });

  final File file;
  final GpxRouteData route;

  @override
  State<PrevisualizarGpxScreen> createState() => _PrevisualizarGpxScreenState();
}

class _PrevisualizarGpxScreenState extends State<PrevisualizarGpxScreen> {
  bool _isImporting = false;

  Future<void> _importRoute() async {
    setState(() => _isImporting = true);
    try {
      await GpxImportService().importFile(
        source: widget.file,
        name: widget.route.name,
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
            Expanded(child: _GpxMap(points: points)),
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
        ),
      ),
    );
  }
}

class _GpxMap extends StatelessWidget {
  const _GpxMap({required this.points});

  final List<LatLng> points;

  @override
  Widget build(BuildContext context) {
    final center = _centerOf(points);
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
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

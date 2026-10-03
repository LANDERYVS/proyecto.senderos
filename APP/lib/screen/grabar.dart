import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/compartir_ubicacion.dart';
import '../widgets/barra_navegacion.dart';
import '../widgets/compartir_ubicacion_button.dart';
import '../widgets/grabar_metrics_panel.dart';
import '../utils/route_calculator.dart';
import 'grabar_controller.dart';
import 'grabar_styles.dart';
import 'inicio.dart';

class GrabarPage extends StatefulWidget {
  const GrabarPage({
    super.key,
    this.initialRoutePoints = const [],
    this.senderoId,
  });

  final List<LatLng> initialRoutePoints;
  final int? senderoId;

  @override
  State<GrabarPage> createState() => _GrabarPageState();
}

class _GrabarPageState extends State<GrabarPage> {
  final GrabarController _controller = GrabarController();
  final CompartirUbicacionService _sharingService = CompartirUbicacionService();
  final DraggableScrollableController _markerSheetController =
      DraggableScrollableController();

  @override
  void initState() {
    super.initState();
    if (widget.initialRoutePoints.isNotEmpty) {
      _controller.recordedRoute.addAll(widget.initialRoutePoints);
    }
    _controller.addListener(_onControllerChanged);
    _loadOfflineMap();
    _controller.requestPermissionAndStartTracking();

    if (widget.initialRoutePoints.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || widget.initialRoutePoints.isEmpty) return;
        final center = RouteCalculator.centerOfPoints(
          widget.initialRoutePoints,
        )!;
        _controller.mapController.move(center, 14);
      });
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sharingService.dispose();
    _markerSheetController.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadOfflineMap() async {
    await _controller.loadOfflineMap();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _toggleRecording() async {
    await _controller.toggleRecording();
    if (!mounted) return;
    setState(() {});

    if (!_controller.isRecording) {
      await _stopSharingIfActive();
      if (!mounted || !context.mounted) return;
      await _controller.finishAndSaveRoute(context);
      if (mounted) setState(() {});
    }
  }

  Future<void> _stopSharingIfActive() async {
    if (_sharingService.sharingFriend == null) return;
    try {
      await _sharingService.stopSharing();
    } on Exception catch (error) {
      debugPrint('No se pudo detener la compartición de ubicación: $error');
    }
  }

  void _togglePause() {
    _controller.togglePause();
    if (mounted) setState(() {});
  }

  Future<void> _addInterestPoint(LatLng point) async {
    await _controller.addInterestPoint(context, point);
    if (mounted) setState(() {});
  }

  Future<void> _selectDestination(int index) async {
    if (index == 2) return;

    final shouldLeave = await _controller.confirmExitIfRecording(context);
    if (!shouldLeave || !mounted) return;
    await _stopSharingIfActive();
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomePage(initialIndex: index)),
    );
  }

  Widget _buildMapContent(LatLng initialCenter) {
    final markerOffsets = _interestPointOffsets();
    return FlutterMap(
      mapController: _controller.mapController,
      options: MapOptions(
        initialCenter: initialCenter,
        initialZoom: widget.initialRoutePoints.isNotEmpty ? 15 : 14,
        onLongPress: (_, point) => _addInterestPoint(point),
      ),
      children: [
        _controller.offlineTileLayer ??
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.proyecto',
            ),
        MarkerLayer(markers: _controller.markers),
        MarkerLayer(
          markers: [
            for (
              var index = 0;
              index < _controller.interestPoints.length;
              index++
            )
              Marker(
                width: 132,
                height: 76,
                point: _controller.interestPoints[index].point,
                child: Transform.translate(
                  offset: markerOffsets[index]!,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _controller.interestPoints[index].type?.icon ??
                            Icons.place,
                        color:
                            _controller.interestPoints[index].type?.color ??
                            GrabarStyles.primaryGreen,
                        size: 34,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        color: Colors.white,
                        child: Text(
                          _controller.interestPoints[index].name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        if (_controller.recordedRoute.length > 1)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _controller.recordedRoute,
                color: GrabarStyles.primaryPink,
                strokeWidth: 7,
              ),
            ],
          ),
        if (_controller.recordedRoute.isNotEmpty)
          MarkerLayer(
            markers: [
              if (_controller.recordedRoute.length > 1)
                Marker(
                  width: 42,
                  height: 48,
                  point: _controller.recordedRoute.last,
                  child: const Icon(Icons.flag, color: Colors.red, size: 34),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildShareButton() {
    if (widget.senderoId == null && !_controller.isRecording) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      left: 16,
      child: SafeArea(
        child: CompartirUbicacionButton(
          sharingService: _sharingService,
          heroTag: 'share-location',
          senderoId: widget.senderoId,
          getCurrentLocation: () async => _controller.markers.isEmpty
              ? null
              : _controller.markers.first.point,
        ),
      ),
    );
  }

  Widget _buildCenterLocationButton() {
    return Positioned(
      top: 16,
      right: 16,
      child: Material(
        color: Colors.white,
        elevation: 3,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: 'Centrar en mi ubicación',
          onPressed: _controller.markers.isEmpty
              ? null
              : () => _controller.mapController.move(
                  _controller.markers.first.point,
                  16,
                ),
          icon: const Icon(Icons.my_location_outlined),
          color: GrabarStyles.primaryGreen,
        ),
      ),
    );
  }

  Widget _buildMarkerPicker() {
    return Positioned.fill(
      child: DraggableScrollableSheet(
        controller: _markerSheetController,
        initialChildSize: 0.11,
        minChildSize: 0.11,
        maxChildSize: 0.34,
        snap: true,
        builder: (context, scrollController) => AnimatedBuilder(
          animation: _markerSheetController,
          builder: (context, _) {
            final showMarkerIcons =
                _markerSheetController.isAttached &&
                _markerSheetController.size >= 0.27;
            return Material(
              color: Theme.of(context).colorScheme.surface,
              elevation: 8,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              clipBehavior: Clip.antiAlias,
              child: ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  InkWell(
                    onTap: _toggleMarkerPicker,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 18,
                          child: Center(
                            child: Container(
                              width: 32,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.outlineVariant,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 2, 20, 8),
                          child: Center(
                            child: Text(
                              'MARCADORES',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Visibility(
                    visible: showMarkerIcons,
                    maintainState: true,
                    maintainAnimation: true,
                    maintainSize: true,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      child: Row(
                        children: [
                          for (final type in GrabarMarkerType.values)
                            Expanded(
                              child: _MarkerTypeButton(
                                type: type,
                                onTap: () => _controller
                                    .addCurrentLocationMarker(context, type),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleMarkerPicker() {
    if (!_markerSheetController.isAttached) return;
    final targetSize = _markerSheetController.size < 0.2 ? 0.34 : 0.11;
    _markerSheetController.animateTo(
      targetSize,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Map<int, Offset> _interestPointOffsets() {
    final points = _controller.interestPoints;
    final offsets = {
      for (var index = 0; index < points.length; index++) index: Offset.zero,
    };
    final ungrouped = Set<int>.from(offsets.keys);

    while (ungrouped.isNotEmpty) {
      final cluster = <int>{ungrouped.first};
      var grew = true;
      while (grew) {
        grew = false;
        for (final candidate in ungrouped) {
          if (cluster.contains(candidate)) continue;
          if (cluster.any(
            (member) =>
                _controller.routeCalculator.calculateIncrementMeters(
                  points[member].point,
                  points[candidate].point,
                ) <=
                24,
          )) {
            cluster.add(candidate);
            grew = true;
          }
        }
      }
      ungrouped.removeAll(cluster);
      if (cluster.length < 2) continue;

      final orderedCluster = cluster.toList()..sort();
      final spread = math.max(1.0, orderedCluster.length / 4);
      for (var index = 0; index < orderedCluster.length; index++) {
        final angle =
            -math.pi / 2 + 2 * math.pi * index / orderedCluster.length;
        offsets[orderedCluster[index]] = Offset(
          math.cos(angle) * 160 * spread,
          math.sin(angle) * 100 * spread,
        );
      }
    }

    return offsets;
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.initialRoutePoints.isNotEmpty
        ? RouteCalculator.centerOfPoints(widget.initialRoutePoints)!
        : _controller.initialPosition;

    return PopScope(
      canPop: !_controller.isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          await _stopSharingIfActive();
          return;
        }
        if (!_controller.isRecording) return;

        final navigator = Navigator.of(context);
        final shouldLeave = await _controller.confirmExitIfRecording(context);
        if (!mounted || !shouldLeave) return;
        await _stopSharingIfActive();
        if (!mounted) return;

        if (navigator.canPop()) {
          navigator.pop();
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _buildMapContent(initialCenter),
                  _buildShareButton(),
                  _buildCenterLocationButton(),
                  _buildMarkerPicker(),
                ],
              ),
            ),
            GrabarMetricsPanel(
              duration: _controller.formattedDuration,
              distanceKm: _controller.distanceKm,
              elevationGainMeters: _controller.elevationGainMeters,
              isRecording: _controller.isRecording,
              isPaused: _controller.isPaused,
              status: _controller.isRecording
                  ? _controller.recordingStatus
                  : null,
              onStart: _controller.isRecording ? null : _toggleRecording,
              onTogglePause: _controller.isRecording ? _togglePause : null,
              onStop: _controller.isRecording ? _toggleRecording : null,
            ),
          ],
        ),
        bottomNavigationBar: buildNavigationBar(
          selectedIndex: 2,
          onDestinationSelected: _selectDestination,
        ),
      ),
    );
  }
}

class _MarkerTypeButton extends StatelessWidget {
  const _MarkerTypeButton({required this.type, required this.onTap});

  final GrabarMarkerType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final background = Color.alphaBlend(
      type.color.withValues(alpha: 0.11),
      Theme.of(context).colorScheme.surface,
    );

    return Tooltip(
      message: 'Agregar ${type.label} en mi ubicación',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 54,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(type.icon, color: type.color, size: 24),
              ),
              const SizedBox(height: 4),
              Text(
                type.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

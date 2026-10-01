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
            for (final interestPoint in _controller.interestPoints)
              Marker(
                width: 120,
                height: 70,
                point: interestPoint.point,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.place,
                      color: GrabarStyles.primaryGreen,
                      size: 34,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      color: Colors.white,
                      child: Text(
                        interestPoint.name,
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
      right: 16,
      bottom: 16,
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

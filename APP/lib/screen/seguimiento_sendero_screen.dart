import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/compartir_ubicacion.dart';
import '../services/offline_tile_service.dart';
import '../widgets/confirm_exit_recording_dialog.dart';
import '../widgets/compartir_ubicacion_button.dart';
import '../widgets/grabar_metrics_panel.dart';
import '../widgets/seguimiento_sendero_map.dart';
import 'seguimiento_sendero_controller.dart';

class SeguimientoSenderoScreen extends StatefulWidget {
  const SeguimientoSenderoScreen({
    super.key,
    required this.routePoints,
    required this.title,
    required this.exitMessage,
    required this.unavailableMapMessage,
    this.offlineRegionId,
    this.senderoId,
  });

  final List<LatLng> routePoints;
  final String title;
  final String exitMessage;
  final String unavailableMapMessage;
  final String? offlineRegionId;
  final int? senderoId;

  @override
  State<SeguimientoSenderoScreen> createState() =>
      _SeguimientoSenderoScreenState();
}

class _SeguimientoSenderoScreenState extends State<SeguimientoSenderoScreen> {
  final MapController _mapController = MapController();
  final OfflineTileService _tileService = OfflineTileService();
  final CompartirUbicacionService _sharingService = CompartirUbicacionService();
  late final SeguimientoSenderoController _trackingController;

  TileLayer? _offlineTileLayer;
  bool _isLoadingMap = false;
  bool _allowPop = false;

  @override
  void initState() {
    super.initState();
    _trackingController = SeguimientoSenderoController(
      routePoints: widget.routePoints,
      mapController: _mapController,
    )..addListener(_refresh);
    _trackingController.start();
    _isLoadingMap = widget.offlineRegionId != null;
    _loadOfflineMap();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _loadOfflineMap() async {
    final regionId = widget.offlineRegionId;
    if (regionId == null) return;
    try {
      final layer = await _tileService.offlineTileLayerIfAvailable(
        regionId: regionId,
      );
      if (mounted && layer != null) setState(() => _offlineTileLayer = layer);
    } on Exception catch (error) {
      debugPrint('No se pudo cargar el mapa offline: $error');
    } finally {
      if (mounted) setState(() => _isLoadingMap = false);
    }
  }

  Future<void> _confirmExit() async {
    final shouldExit = await showConfirmExitRecordingDialog(
      context: context,
      message: widget.exitMessage,
      title: '¿Terminar seguimiento?',
      continueLabel: 'Continuar',
      exitLabel: 'Detener seguimiento',
    );
    if (!mounted || !shouldExit) return;
    await _stopSharingIfActive();
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _stopSharingIfActive() async {
    if (_sharingService.sharingFriend == null) return;
    try {
      await _sharingService.stopSharing();
    } on Exception catch (error) {
      debugPrint('No se pudo detener la compartición de ubicación: $error');
    }
  }

  @override
  void dispose() {
    _sharingService.dispose();
    _trackingController
      ..removeListener(_refresh)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _trackingController;
    final routePoints = widget.routePoints;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && !_allowPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.title)),
        body: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  SeguimientoSenderoMap(
                    mapController: _mapController,
                    routePoints: routePoints,
                    initialCenter: controller.initialCenter,
                    userLocation: controller.userLocation,
                    isLoadingLocation: controller.isLoadingLocation,
                    isLoadingMap: _isLoadingMap,
                    offlineOnly: widget.offlineRegionId != null,
                    unavailableMessage: widget.unavailableMapMessage,
                    onCenterOnUserLocation: controller.userLocation == null
                        ? null
                        : controller.centerOnUserLocation,
                    tileLayer: _offlineTileLayer,
                    initialZoom: routePoints.isEmpty ? 13 : 15,
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: SafeArea(
                      child: CompartirUbicacionButton(
                        sharingService: _sharingService,
                        heroTag: 'share-follow-location',
                        senderoId: widget.senderoId,
                        getCurrentLocation: () async => controller.userLocation,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            GrabarMetricsPanel(
              duration: controller.formattedDuration,
              distanceKm: controller.distanceKm,
              elevationGainMeters: controller.elevationGainMeters,
              isRecording: true,
              isPaused: controller.isPaused,
              status: 'Seguimiento activo',
              statusLabel: 'SIGUIENDO',
              onTogglePause: controller.togglePause,
              onStop: _confirmExit,
              stopLabel: 'Finalizar',
            ),
          ],
        ),
      ),
    );
  }
}

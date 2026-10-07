import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/trail_waypoint.dart';
import '../services/compartir_ubicacion.dart';
import '../services/offline_tile_service.dart';
import '../services/ubicacion_app.dart';
import '../services/walking_stats_service.dart';
import '../widgets/confirm_exit_recording_dialog.dart';
import '../widgets/compartir_ubicacion_button.dart';
import '../widgets/enviar_alerta_button.dart';
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
    this.waypoints = const [],
  });

  final List<LatLng> routePoints;
  final String title;
  final String exitMessage;
  final String unavailableMapMessage;
  final String? offlineRegionId;
  final int? senderoId;
  final List<TrailWaypoint> waypoints;

  @override
  State<SeguimientoSenderoScreen> createState() =>
      _SeguimientoSenderoScreenState();
}

class _SeguimientoSenderoScreenState extends State<SeguimientoSenderoScreen> {
  final MapController _mapController = MapController();
  final OfflineTileService _tileService = OfflineTileService();
  final CompartirUbicacionService _sharingService = CompartirUbicacionService();
  final WalkingStatsService _walkingStatsService = WalkingStatsService();
  late final SeguimientoSenderoController _trackingController;

  TileLayer? _offlineTileLayer;
  bool _isLoadingMap = false;
  bool _allowPop = false;
  bool _stoppingSharing = false;
  bool _isSharingLocation = false;

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
    if (!UbicacionApp.enabled.value) unawaited(_stopSharingIfActive());
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
    _trackingController.stopTracking();
    try {
      await _walkingStatsService.recordCompletedWalk(
        distanceKm: _trackingController.distanceKm,
      );
    } on WalkingStatsException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      debugPrint('No se pudieron registrar los kilómetros caminados: $error');
      return;
    }
    if (!mounted) return;
    await _stopSharingIfActive();
    if (!mounted) return;
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
  }

  Future<void> _stopSharingIfActive() async {
    if (_stoppingSharing || _sharingService.sharingFriend == null) return;
    _stoppingSharing = true;
    try {
      await _sharingService.stopSharing();
      if (mounted) setState(() => _isSharingLocation = false);
    } on Exception catch (error) {
      debugPrint('No se pudo detener la compartición de ubicación: $error');
    } finally {
      _stoppingSharing = false;
    }
  }

  void _onSharingChanged() {
    if (!mounted) return;
    setState(() => _isSharingLocation = _sharingService.sharingFriend != null);
  }

  Future<void> _openDirectionsToStart() async {
    if (widget.routePoints.isEmpty) return;

    final start = widget.routePoints.first;
    final mapsUri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${start.latitude},${start.longitude}',
      'travelmode': 'walking',
      'dir_action': 'navigate',
    });

    try {
      final launched = await launchUrl(
        mapsUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir Google Maps')),
        );
      }
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir Google Maps: $error')),
      );
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
                    waypoints: widget.waypoints,
                  ),
                  Positioned(
                    top: 16,
                    left: 16,
                    child: SafeArea(
                      child: CompartirUbicacionButton(
                        sharingService: _sharingService,
                        heroTag: 'share-follow-location',
                        senderoId: widget.senderoId,
                        onSharingChanged: _onSharingChanged,
                        getCurrentLocation: () async => controller.userLocation,
                      ),
                    ),
                  ),
                  if (_isSharingLocation)
                    Positioned(
                      top: 16,
                      left: 72,
                      child: SafeArea(
                        child: EnviarAlertaButton(
                          sharingService: _sharingService,
                          senderoId: widget.senderoId,
                        ),
                      ),
                    ),
                  if (routePoints.isNotEmpty)
                    Positioned(
                      right: 16,
                      bottom: 16,
                      child: SafeArea(
                        child: FilledButton.icon(
                          onPressed: _openDirectionsToStart,
                          icon: const Icon(Icons.directions),
                          label: const Text('Cómo llegar al inicio'),
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

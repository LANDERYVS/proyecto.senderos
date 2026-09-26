import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/compartir_ubicacion.dart';
import '../widgets/barra_navegacion.dart';
import 'grabar_controller.dart';
import 'grabar_styles.dart';
import 'inicio.dart';
import 'perfil.dart';
import '../widgets/grabar_action_button.dart';
import '../widgets/grabar_metric_indicator.dart';

class GrabarPage extends StatefulWidget {
  const GrabarPage({
    super.key,
    this.initialRoutePoints = const [],
    this.routeName,
  });

  final List<LatLng> initialRoutePoints;
  final String? routeName;

  @override
  State<GrabarPage> createState() => _GrabarPageState();
}

class _GrabarPageState extends State<GrabarPage> {
  final GrabarController _controller = GrabarController();
  final CompartirUbicacionService _locationSharing =
      CompartirUbicacionService();

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
        final center = _centerOf(widget.initialRoutePoints);
        _controller.mapController.move(center, 14);
      });
    }
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _locationSharing.dispose();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  LatLng _centerOf(List<LatLng> points) {
    final latitude = points.fold<double>(0, (sum, point) => sum + point.latitude);
    final longitude = points.fold<double>(0, (sum, point) => sum + point.longitude);
    return LatLng(latitude / points.length, longitude / points.length);
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
      if (!mounted || !context.mounted) return;
      await _controller.finishAndSaveRoute(context);
      if (mounted) setState(() {});
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

  Future<void> _chooseFriendForSharing() async {
    try {
      final friends = await _locationSharing.loadFriends();
      if (friends.isEmpty) {
        _showMessage('Primero agrega un amigo desde Comunidad.');
        return;
      }

      if (!mounted) return;
      final selectedFriend = await showModalBottomSheet<ShareFriend>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const ListTile(
                title: Text(
                  'Compartir mi ubicación',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Elige un amigo para verla en su mapa.'),
              ),
              for (final friend in friends)
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline),
                  ),
                  title: Text(friend.name),
                  subtitle: friend.email.isEmpty ? null : Text(friend.email),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.pop(context, friend),
                ),
            ],
          ),
        ),
      );

      if (selectedFriend == null) return;
      await _startSharingWith(selectedFriend);
    } on Exception catch (error) {
      _showMessage('No se pudieron cargar tus amigos: $error');
    }
  }

  Future<void> _startSharingWith(ShareFriend friend) async {
    try {
      await _locationSharing.startSharing(friend, _publishCurrentLocation);
      if (mounted) {
        setState(() {});
        _showMessage('Ubicación compartida con ${friend.name}.');
      }
    } on Exception catch (error) {
      _showMessage('No se pudo compartir la ubicación: ${_errorText(error)}');
    }
  }

  Future<void> _publishCurrentLocation() async {
    if (_controller.markers.isEmpty) {
      throw StateError('Todavía no hay una ubicación GPS disponible.');
    }
    await _locationSharing.publishLocation(_controller.markers.first);
  }

  Future<void> _stopSharing() async {
    try {
      await _locationSharing.stopSharing();
      if (mounted) {
        setState(() {});
        _showMessage('Dejaste de compartir tu ubicación.');
      }
    } on Exception catch (error) {
      _showMessage('No se pudo detener el envío: ${_errorText(error)}');
    }
  }

  String _errorText(Object error) {
    if (error is StateError) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectDestination(int index) async {
    if (index == 2) return;

    final shouldLeave = await _controller.confirmExitIfRecording(context);
    if (!shouldLeave || !mounted) return;

    if (index == 4) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ProfilePage()),
      );
      return;
    }

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
                    const Icon(
                      Icons.place,
                      color: Colors.deepPurple,
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
                  child: const Icon(
                    Icons.flag,
                    color: Colors.red,
                    size: 34,
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildShareButton() {
    final isSharing = _locationSharing.sharingFriend != null;
    return Positioned(
      top: 16,
      left: 16,
      child: SafeArea(
        child: FloatingActionButton.small(
          heroTag: 'share-location',
          tooltip: isSharing ? 'Dejar de compartir ubicación' : 'Compartir ubicación',
          backgroundColor: isSharing ? Colors.green : Colors.white,
          foregroundColor: isSharing ? Colors.white : Colors.black87,
          onPressed: isSharing ? _stopSharing : _chooseFriendForSharing,
          child: Icon(
            isSharing ? Icons.location_on : Icons.location_on_outlined,
          ),
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

  Widget _buildRecordingActions() {
    if (_controller.isRecording) {
      return Row(
        children: [
          Expanded(
            child: GrabarActionButton(
              isRecording: true,
              onPressed: _togglePause,
              label: _controller.isPaused ? 'Reanudar' : 'Pausar',
              icon: _controller.isPaused ? Icons.play_arrow : Icons.pause,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: GrabarActionButton(
              isRecording: true,
              onPressed: _toggleRecording,
              label: 'Detener',
              icon: Icons.stop,
              style: GrabarStyles.stopButtonStyle,
            ),
          ),
        ],
      );
    }

    return GrabarActionButton(
      isRecording: false,
      onPressed: _toggleRecording,
      label: 'Iniciar trayecto',
      icon: Icons.play_arrow,
      style: GrabarStyles.primaryButtonStyle,
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = widget.initialRoutePoints.isNotEmpty
        ? _centerOf(widget.initialRoutePoints)
        : _controller.initialPosition;

    return PopScope(
      canPop: !_controller.isRecording,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !_controller.isRecording) return;

        final navigator = Navigator.of(context);
        final shouldLeave = await _controller.confirmExitIfRecording(context);
        if (!mounted || !shouldLeave) return;

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
            Container(
              color: GrabarStyles.panelBackground,
              padding: GrabarStyles.panelPadding,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GrabarMetricIndicator(
                        label: 'TIEMPO',
                        value: _controller.formattedDuration,
                      ),
                      GrabarMetricIndicator(
                        label: 'DISTANCIA',
                        value: '${_controller.distanceKm.toStringAsFixed(1)} km',
                        alignment: CrossAxisAlignment.end,
                      ),
                      GrabarMetricIndicator(
                        label: 'SUBIDA',
                        value: '${_controller.elevationGainMeters.toStringAsFixed(0)} m',
                        alignment: CrossAxisAlignment.end,
                      ),
                    ],
                  ),
                  if (_controller.isRecording) ...[
                    const SizedBox(height: 5),
                    Text(
                      _controller.recordingStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GrabarStyles.statusStyle(context),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildRecordingActions(),
                  if (_controller.status.isNotEmpty && !_controller.isRecording) ...[
                    const SizedBox(height: 6),
                    Text(
                      _controller.status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GrabarStyles.statusStyle(context),
                    ),
                  ],
                ],
              ),
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

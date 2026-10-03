import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/compartir_ubicacion.dart';
import '../services/gpx_import.dart';
import '../widgets/default_user_avatar.dart';

class EspectadorContent extends StatefulWidget {
  const EspectadorContent({super.key});

  @override
  State<EspectadorContent> createState() => _EspectadorContentState();
}

class _EspectadorContentState extends State<EspectadorContent> {
  final CompartirUbicacionService _locationService =
      CompartirUbicacionService();
  List<ObservedTrailGroup> _trailGroups = const [];
  final Map<int, List<LatLng>> _routePointsByTrailId = {};
  final Set<int> _loadingTrailIds = {};
  String? _errorMessage;
  bool _isLoading = true;
  bool _isLoadingGroups = false;
  bool _isRefreshingLocations = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadObservedTrails();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadObservedTrails(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _loadObservedTrails() async {
    if (_isLoadingGroups) return;
    _isLoadingGroups = true;
    if (_trailGroups.isEmpty && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }
    try {
      final groups = await _locationService.loadObservedTrails();
      if (!mounted) return;
      setState(() {
        _trailGroups = groups;
        _isLoading = false;
        _errorMessage = null;
      });
      await Future.wait(groups.map(_loadTrailPreview));
      await _refreshLocations();
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar los espectadores: $error';
        _isLoading = false;
      });
    } finally {
      _isLoadingGroups = false;
    }
  }

  Future<void> _refreshLocations() async {
    if (_isRefreshingLocations || _trailGroups.isEmpty) return;
    _isRefreshingLocations = true;
    try {
      final friendIds = _trailGroups
          .expand((group) => group.observers)
          .map((friend) => friend.id)
          .toSet();
      final locations = await _locationService.loadLocations(friendIds);
      if (!mounted) return;
      setState(() {
        _trailGroups = _trailGroups
            .map(
              (group) => group.withObservers(
                group.observers
                    .map((friend) => friend.withLocation(locations[friend.id]))
                    .toList(),
              ),
            )
            .toList();
      });
    } on Exception catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron actualizar las ubicaciones: $error';
      });
    } finally {
      _isRefreshingLocations = false;
    }
  }

  Future<void> _loadTrailPreview(ObservedTrailGroup group) async {
    final url = group.gpxUrl;
    if (url == null ||
        _routePointsByTrailId.containsKey(group.trailId) ||
        _loadingTrailIds.contains(group.trailId)) {
      return;
    }
    if (mounted) setState(() => _loadingTrailIds.add(group.trailId));
    try {
      final route = await GpxImportService().readUrl(url);
      if (!mounted) return;
      setState(() => _routePointsByTrailId[group.trailId] = route.points);
    } on Exception {
      if (mounted) {
        setState(() => _routePointsByTrailId[group.trailId] = const []);
      }
    } finally {
      if (mounted) setState(() => _loadingTrailIds.remove(group.trailId));
    }
  }

  int get _observerCount => _trailGroups
      .expand((group) => group.observers)
      .map((friend) => friend.id)
      .toSet()
      .length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUser = Supabase.instance.client.auth.currentUser;
    final metadataName = currentUser?.userMetadata?['name']?.toString().trim();
    final viewerName = metadataName?.isNotEmpty == true
        ? metadataName!
        : currentUser?.email?.split('@').first ?? 'Usuario';
    final viewerPhoto = currentUser?.userMetadata?['avatar_url']?.toString();

    return Column(
      children: [
        _buildViewerHeader(
          colorScheme,
          viewerName: viewerName,
          viewerPhoto: viewerPhoto,
        ),
        ListTile(
          leading: Icon(Icons.route_outlined, color: colorScheme.primary),
          title: const Text(
            'Senderos y trayectos que estás supervisando',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          trailing: Text('${_trailGroups.length}'),
        ),
        const Divider(height: 1),
        Expanded(child: _buildTrailList(colorScheme)),
      ],
    );
  }

  Widget _buildViewerHeader(
    ColorScheme colorScheme, {
    required String viewerName,
    required String? viewerPhoto,
  }) {
    return Container(
      color: colorScheme.primary,
      padding: const EdgeInsets.fromLTRB(20, 12, 76, 16),
      child: Row(
        children: [
          DefaultUserAvatar(radius: 30, imageUrl: viewerPhoto),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  viewerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'ESPECTADOR',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.visibility,
                      size: 18,
                      color: colorScheme.onPrimary,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        'Observando a $_observerCount '
                        '${_observerCount == 1 ? 'usuario' : 'usuarios'}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onPrimary,
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
    );
  }

  Widget _buildTrailList(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null && _trailGroups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_errorMessage!, textAlign: TextAlign.center),
              TextButton.icon(
                onPressed: _loadObservedTrails,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (_trailGroups.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadObservedTrails,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 48),
            Center(
              child: Text(
                'No hay senderos ni trayectos activos para supervisar.',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadObservedTrails,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _trailGroups.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) =>
            _buildTrailCard(_trailGroups[index], colorScheme),
      ),
    );
  }

  Widget _buildTrailCard(ObservedTrailGroup group, ColorScheme colorScheme) {
    final routePoints = _routePointsByTrailId[group.trailId] ?? const [];
    final visibleObservers = group.observers.take(3).toList();
    final remainingCount = group.observers.length - visibleObservers.length;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.12),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute<void>(
            builder: (_) =>
                _ObservedTrailMapPage(group: group, routePoints: routePoints),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Row(
                children: [
                  Icon(Icons.route_outlined, color: colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text('${group.observers.length}'),
                ],
              ),
            ),
            if (_loadingTrailIds.contains(group.trailId))
              const SizedBox(
                height: 172,
                child: Center(child: CircularProgressIndicator()),
              )
            else if (group.isLive)
              _ObservedTrailMap(
                points: routePoints,
                observers: group.observers,
                colorScheme: colorScheme,
                height: 172,
                interactive: false,
              )
            else if (routePoints.length > 1)
              _ObservedTrailMap(
                points: routePoints,
                observers: group.observers,
                colorScheme: colorScheme,
                height: 172,
                interactive: false,
              )
            else if (group.photoUrl != null)
              Image.network(
                group.photoUrl!,
                height: 172,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _unavailableRoutePreview(colorScheme),
              )
            else
              _unavailableRoutePreview(colorScheme),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    height: 38,
                    child: Stack(
                      children: [
                        for (
                          var index = 0;
                          index < visibleObservers.length;
                          index++
                        )
                          Positioned(
                            left: index * 22,
                            child: Tooltip(
                              message: visibleObservers[index].name,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: colorScheme.surface,
                                  shape: BoxShape.circle,
                                ),
                                child: DefaultUserAvatar(
                                  radius: 16,
                                  imageUrl: visibleObservers[index].photoUrl,
                                ),
                              ),
                            ),
                          ),
                        if (remainingCount > 0)
                          Positioned(
                            left: visibleObservers.length * 22,
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Text('+$remainingCount'),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${group.observers.length} '
                      '${group.observers.length == 1 ? 'persona supervisando' : 'personas supervisando'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _unavailableRoutePreview(ColorScheme colorScheme) => Container(
    height: 172,
    color: colorScheme.surfaceContainerHighest,
    alignment: Alignment.center,
    child: const Text('Trayecto no disponible'),
  );
}

class _ObservedTrailMap extends StatelessWidget {
  const _ObservedTrailMap({
    required this.points,
    required this.observers,
    required this.colorScheme,
    this.mapKey,
    this.height = 132,
    this.interactive = false,
  });

  final List<LatLng> points;
  final List<ShareFriend> observers;
  final ColorScheme colorScheme;
  final Key? mapKey;
  final double? height;
  final bool interactive;

  @override
  Widget build(BuildContext context) {
    final visiblePoints = [
      ...points,
      for (final observer in observers)
        if (observer.location != null) observer.location!,
    ];
    if (visiblePoints.isEmpty) {
      final message = ColoredBox(
        color: colorScheme.surfaceContainerHighest,
        child: const Center(child: Text('Ubicación no disponible')),
      );
      return height == null
          ? SizedBox.expand(child: message)
          : SizedBox(height: height, child: message);
    }
    final bounds = visiblePoints.length > 1
        ? LatLngBounds.fromPoints(visiblePoints)
        : null;

    final map = ClipRect(
      child: FlutterMap(
        key: mapKey,
        options: MapOptions(
          initialCenter: visiblePoints.first,
          initialZoom: 13,
          initialCameraFit: bounds == null
              ? null
              : CameraFit.bounds(
                  bounds: bounds,
                  padding: const EdgeInsets.all(24),
                ),
          interactionOptions: InteractionOptions(
            flags: interactive ? InteractiveFlag.all : InteractiveFlag.none,
          ),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'proyecto.senderos',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: points,
                color: colorScheme.primary,
                strokeWidth: 5,
              ),
            ],
          ),
          MarkerLayer(
            markers: [
              for (final observer in observers)
                if (observer.location case final location?)
                  Marker(
                    point: location,
                    width: 280,
                    height: 48,
                    alignment: Alignment.center,
                    child: Row(
                      children: [
                        const SizedBox(width: 121),
                        SizedBox(
                          width: 38,
                          height: 38,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              shape: BoxShape.circle,
                              border: Border.all(color: colorScheme.primary),
                            ),
                            child: DefaultUserAvatar(
                              radius: 17,
                              imageUrl: observer.photoUrl,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: colorScheme.surface,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: colorScheme.outlineVariant,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.shadow.withValues(
                                      alpha: 0.16,
                                    ),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 5,
                                ),
                                child: Text(
                                  observer.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.labelMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ],
      ),
    );
    return height == null
        ? SizedBox.expand(child: map)
        : SizedBox(height: height, child: map);
  }
}

class _ObservedTrailMapPage extends StatefulWidget {
  const _ObservedTrailMapPage({required this.group, required this.routePoints});

  final ObservedTrailGroup group;
  final List<LatLng> routePoints;

  @override
  State<_ObservedTrailMapPage> createState() => _ObservedTrailMapPageState();
}

class _ObservedTrailMapPageState extends State<_ObservedTrailMapPage> {
  final CompartirUbicacionService _locationService =
      CompartirUbicacionService();
  late ObservedTrailGroup _group;
  late List<LatLng> _routePoints;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  bool _isLoadingRoute = false;
  int _mapRevision = 0;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _routePoints = widget.routePoints;
    if (_routePoints.isEmpty && widget.group.gpxUrl != null) {
      _loadRoute();
    }
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshLocations(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _loadRoute() async {
    final url = widget.group.gpxUrl;
    if (url == null) return;
    setState(() => _isLoadingRoute = true);
    try {
      final route = await GpxImportService().readUrl(url);
      if (mounted) setState(() => _routePoints = route.points);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo cargar el sendero.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingRoute = false);
    }
  }

  Future<void> _refreshLocations({bool refreshMap = false}) async {
    if (_isRefreshing) return;
    if (refreshMap) {
      setState(() => _isRefreshing = true);
    } else {
      _isRefreshing = true;
    }
    try {
      if (_group.observers.isNotEmpty) {
        final locations = await _locationService.loadLocations(
          _group.observers.map((observer) => observer.id),
        );
        if (!mounted) return;
        setState(() {
          _group = _group.withObservers(
            _group.observers
                .map(
                  (observer) => observer.withLocation(locations[observer.id]),
                )
                .toList(),
          );
        });
      }
    } on Exception catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudieron actualizar las ubicaciones: $error'),
        ),
      );
    } finally {
      _isRefreshing = false;
      if (mounted && refreshMap) {
        setState(() {
          _mapRevision++;
        });
      }
    }
  }

  Future<void> _callObserver(ShareFriend observer) async {
    final phone = observer.phone?.replaceAll(RegExp(r'[^0-9+]'), '') ?? '';
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${observer.name} no tiene teléfono registrado.'),
        ),
      );
      return;
    }
    final launched = await launchUrl(Uri(scheme: 'tel', path: phone));
    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir la aplicación de llamadas.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_group.name),
        actions: [
          IconButton(
            tooltip: 'Actualizar ubicaciones',
            onPressed: _isRefreshing
                ? null
                : () => _refreshLocations(refreshMap: true),
            icon: _isRefreshing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _ObservedTrailMap(
              points: _routePoints,
              observers: _group.observers,
              colorScheme: colorScheme,
              mapKey: ValueKey(_mapRevision),
              height: null,
              interactive: true,
            ),
          ),
          if (_isLoadingRoute)
            const Positioned(
              top: 16,
              right: 16,
              child: CircularProgressIndicator(),
            ),
          Positioned(
            left: 16,
            top: 16,
            child: Material(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Text(
                  '${_group.observers.length} '
                  '${_group.observers.length == 1 ? 'persona supervisando' : 'personas supervisando'}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 68,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _group.observers.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final observer = _group.observers[index];
                    return Material(
                      color: colorScheme.surface,
                      borderRadius: BorderRadius.circular(8),
                      elevation: 3,
                      child: SizedBox(
                        width: 216,
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            DefaultUserAvatar(
                              radius: 20,
                              imageUrl: observer.photoUrl,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                observer.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelLarge,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Llamar a ${observer.name}',
                              onPressed: () => _callObserver(observer),
                              icon: const Icon(Icons.call_outlined),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

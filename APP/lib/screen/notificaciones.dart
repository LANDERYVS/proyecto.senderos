import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/content_state_view.dart';
import '../widgets/default_user_avatar.dart';

class NotificacionesAlertasScreen extends StatefulWidget {
  const NotificacionesAlertasScreen({super.key, required this.onAlertSelected});

  final Future<void> Function(Map<String, dynamic> alert) onAlertSelected;

  @override
  State<NotificacionesAlertasScreen> createState() =>
      _NotificacionesAlertasScreenState();
}

class _NotificacionesAlertasScreenState
    extends State<NotificacionesAlertasScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _alerts = const [];
  Map<String, String> _senderNamesByFriendshipId = const {};
  Map<String, String?> _senderPhotosByFriendshipId = const {};
  Map<String, String> _trailNamesById = const {};
  String? _errorMessage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _alerts = const [];
        _isLoading = false;
        _errorMessage = 'Inicia sesión para consultar tus alertas.';
      });
      return;
    }

    List<Map<String, dynamic>> alerts;
    try {
      final rows = await _client
          .from('notificaciones_alertas')
          .select(
            'id, type, message, status, created_at, sendero_id, amistad_id, espectador_id',
          )
          .eq('espectador_id', user.id)
          .order('created_at', ascending: false);
      alerts = rows
          .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
          .toList();
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _senderNamesByFriendshipId = const {};
        _senderPhotosByFriendshipId = const {};
        _trailNamesById = const {};
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      debugPrint(
        'No se pudieron cargar las alertas '
        '(${error.code ?? 'Supabase'}): ${error.message}',
      );
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar las alertas: ${error.message}';
        _isLoading = false;
      });
      return;
    } catch (error) {
      debugPrint('No se pudieron cargar las alertas: $error');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'No se pudieron cargar las alertas.';
        _isLoading = false;
      });
      return;
    }

    try {
      final friendshipIds = alerts
          .map((alert) => alert['amistad_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final friendships = friendshipIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await _client
                .from('amistades')
                .select('id, users_id, target_id')
                .inFilter('id', friendshipIds);
      final senderIdByFriendshipId = <String, String>{};
      for (final friendship in friendships) {
        final friendshipId = friendship['id'].toString();
        final usersId = friendship['users_id'].toString();
        final targetId = friendship['target_id'].toString();
        final spectatorId = user.id;
        final senderId = usersId == spectatorId ? targetId : usersId;
        senderIdByFriendshipId[friendshipId] = senderId;
      }
      final senderIds = senderIdByFriendshipId.values.toSet().toList();
      final trailIds = alerts
          .map((alert) => alert['sendero_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final profiles = senderIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await _client
                .from('usuarios')
                .select('id, name, email, user_photo')
                .inFilter('id', senderIds);
      final trails = trailIds.isEmpty
          ? <Map<String, dynamic>>[]
          : await _client
                .from('senderos')
                .select('id, sendero_nick')
                .inFilter('id', trailIds);
      final profilesById = {
        for (final profile in profiles) profile['id'].toString(): profile,
      };
      if (!mounted) return;
      setState(() {
        _senderNamesByFriendshipId = {
          for (final entry in senderIdByFriendshipId.entries)
            entry.key: _profileName(profilesById[entry.value]),
        };
        _senderPhotosByFriendshipId = {
          for (final entry in senderIdByFriendshipId.entries)
            entry.key: profilesById[entry.value]?['user_photo']?.toString(),
        };
        _trailNamesById = {
          for (final trail in trails)
            trail['id'].toString():
                trail['sendero_nick']?.toString().trim().isNotEmpty == true
                ? trail['sendero_nick'].toString().trim()
                : 'Sendero sin nombre',
        };
      });
    } on PostgrestException catch (error) {
      debugPrint(
        'No se pudieron completar los nombres de remitente/sendero '
        '(${error.code ?? 'Supabase'}): ${error.message}',
      );
    } catch (error) {
      debugPrint('No se pudieron completar los nombres de las alertas: $error');
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> alert) async {
    if (alert['status'] == true) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('notificaciones_alertas')
          .update({'status': true})
          .eq('id', alert['id'])
          .eq('espectador_id', userId);
      if (!mounted) return;
      setState(() => alert['status'] = true);
    } on PostgrestException catch (error) {
      _showError('No se pudo marcar la alerta como vista: ${error.message}');
    } catch (error) {
      _showError('No se pudo marcar la alerta como vista: $error');
    }
  }

  Future<void> _deleteAlert(Map<String, dynamic> alert) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('notificaciones_alertas')
          .delete()
          .eq('id', alert['id'])
          .eq('espectador_id', userId);
      if (!mounted) return;
      setState(() => _alerts.remove(alert));
    } on PostgrestException catch (error) {
      _showError('No se pudo eliminar la alerta: ${error.message}');
    } catch (error) {
      _showError('No se pudo eliminar la alerta: $error');
    }
  }

  Future<void> _openAlert(Map<String, dynamic> alert) async {
    await _markAsRead(alert);
    if (!mounted) return;
    Navigator.pop(context);
    await widget.onAlertSelected(alert);
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateLabel(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return '';
    final now = DateTime.now();
    final sameDay =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final yesterday =
        DateTime(
          now.year,
          now.month,
          now.day,
        ).difference(DateTime(date.year, date.month, date.day)) ==
        const Duration(days: 1);
    final prefix = sameDay
        ? 'Hoy'
        : yesterday
        ? 'Ayer'
        : '';
    final time =
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    if (prefix.isNotEmpty) return '$prefix, $time';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}, $time';
  }

  String? _firstStringValue(Map<String, dynamic> values, List<String> keys) {
    for (final key in keys) {
      final value = values[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  String _profileName(Map<String, dynamic>? profile) {
    final name = profile?['name']?.toString().trim();
    if (name?.isNotEmpty == true) return name!;
    final email = profile?['email']?.toString().trim();
    return email?.isNotEmpty == true ? email! : 'Senderista';
  }

  String _senderName(Map<String, dynamic> alert) {
    final friendshipId = alert['amistad_id']?.toString();
    final senderName = friendshipId == null
        ? null
        : _senderNamesByFriendshipId[friendshipId];
    if (senderName != null) return senderName;
    final directName = _firstStringValue(alert, ['sender_name']);
    return directName ?? 'Senderista';
  }

  String _trailName(Map<String, dynamic> alert) {
    final directName = _firstStringValue(alert, ['sendero_name']);
    if (directName != null) return directName;
    final trailId = alert['sendero_id']?.toString();
    return trailId == null
        ? 'Trayecto compartido'
        : _trailNamesById[trailId] ?? 'Sendero';
  }

  Color _severityColor(dynamic type) {
    switch (type?.toString().trim().toLowerCase()) {
      case 'aviso':
      case 'notice':
        return Colors.green;
      case 'moderada':
      case 'moderado':
      case 'moderate':
        return Colors.amber;
      case 'peligro':
      case 'danger':
        return Colors.red;
      default:
        return Colors.blueGrey;
    }
  }

  String _severityLabel(dynamic type) {
    final value = type?.toString().trim();
    if (value == null || value.isEmpty) return 'Alerta';
    switch (value.toLowerCase()) {
      case 'notice':
        return 'Aviso';
      case 'moderate':
      case 'moderado':
        return 'Moderada';
      case 'danger':
        return 'Peligro';
      default:
        return value;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _isLoading
          ? const ContentStateView(isLoading: true)
          : _errorMessage != null
          ? ContentStateView(message: _errorMessage!, onRetry: _loadAlerts)
          : _alerts.isEmpty
          ? const ContentStateView(message: 'No tienes alertas.')
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: Theme.of(context).colorScheme.outlineVariant,
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.notifications_active_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Alertas',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadAlerts,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alerts.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final alert = _alerts[index];
                        final isUnread = alert['status'] != true;
                        final severityColor = _severityColor(alert['type']);
                        final friendshipId = alert['amistad_id']?.toString();
                        final photoUrl = friendshipId == null
                            ? null
                            : _senderPhotosByFriendshipId[friendshipId];
                        return Card(
                          margin: EdgeInsets.zero,
                          color: severityColor.withValues(
                            alpha: isUnread ? 0.10 : 0.05,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: severityColor.withValues(alpha: 0.35),
                              width: isUnread ? 1.5 : 1,
                            ),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: () => _openAlert(alert),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  DefaultUserAvatar(
                                    radius: 24,
                                    imageUrl: photoUrl,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _senderName(alert),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              _dateLabel(alert['created_at']),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.bodySmall,
                                            ),
                                            PopupMenuButton<String>(
                                              tooltip: 'Opciones de alerta',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                              onSelected: (value) {
                                                if (value == 'delete') {
                                                  _deleteAlert(alert);
                                                }
                                              },
                                              itemBuilder: (_) => const [
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  child: Text('Eliminar'),
                                                ),
                                              ],
                                              child: const Padding(
                                                padding: EdgeInsets.only(
                                                  left: 4,
                                                ),
                                                child: Icon(
                                                  Icons.more_horiz,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.hiking,
                                              size: 15,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurfaceVariant,
                                            ),
                                            const SizedBox(width: 5),
                                            Expanded(
                                              child: Text(
                                                _trailName(alert),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.bodySmall,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          alert['message']?.toString() ??
                                              'Sin mensaje',
                                          style: TextStyle(
                                            fontWeight: isUnread
                                                ? FontWeight.w600
                                                : FontWeight.w400,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: severityColor,
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          _severityIcon(alert['type']),
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _severityLabel(alert['type']),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  IconData _severityIcon(dynamic type) {
    switch (type?.toString().trim().toLowerCase()) {
      case 'aviso':
      case 'notice':
        return Icons.info_outline;
      case 'moderada':
      case 'moderado':
      case 'moderate':
        return Icons.warning_amber_rounded;
      default:
        return Icons.error_outline;
    }
  }
}

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _client = Supabase.instance.client;
  List<Map<String, dynamic>> _notifications = const [];
  List<Map<String, dynamic>> _sentRequests = const [];
  List<Map<String, dynamic>> _receivedRequests = const [];
  List<Map<String, dynamic>> _sentLocationRequests = const [];
  List<Map<String, dynamic>> _receivedLocationRequests = const [];
  Map<String, Map<String, dynamic>> _profiles = const {};
  final Set<String> _processingRequestIds = {};
  bool _isLoading = true;
  String? _loadError;
  RealtimeChannel? _requestChannel;

  @override
  void initState() {
    super.initState();
    _subscribeToRequests();
    _loadNotifications();
  }

  @override
  void dispose() {
    final channel = _requestChannel;
    if (channel != null) {
      _client.removeChannel(channel);
    }
    super.dispose();
  }

  void _subscribeToRequests() {
    final user = _client.auth.currentUser;
    if (user == null) return;

    _requestChannel = _client
        .channel('notification-requests:${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones_solicitudes',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'target_id',
            value: user.id,
          ),
          callback: (_) => _loadNotifications(),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notificaciones_alertas',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'espectador_id',
            value: user.id,
          ),
          callback: (_) => _loadNotifications(),
        )
        .subscribe();
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Inicia sesión para consultar tus notificaciones.';
      });
      debugPrint('No se cargaron notificaciones: no hay una sesión iniciada.');
      return;
    }

    var loadingStep = 'alertas recibidas';
    try {
      final alerts = await _client
          .from('notificaciones_alertas')
          .select(
            'id, type, message, status, created_at, sendero_id, amistad_id, espectador_id',
          )
          .eq('espectador_id', user.id)
          .order('created_at', ascending: false);
      loadingStep = 'solicitudes de amistad enviadas';
      final sentRequests = await _client
          .from('notificaciones_solicitudes')
          .select('id, users_id, target_id, created_at')
          .eq('users_id', user.id)
          .eq('tipo', 'amistad')
          .order('created_at', ascending: false);
      loadingStep = 'solicitudes de amistad recibidas';
      final receivedRequests = await _client
          .from('notificaciones_solicitudes')
          .select('id, users_id, target_id, created_at')
          .eq('target_id', user.id)
          .eq('tipo', 'amistad')
          .order('created_at', ascending: false);
      loadingStep = 'solicitudes de ubicación enviadas';
      final sentLocationRequests = await _client
          .from('notificaciones_solicitudes')
          .select('id, users_id, target_id, estado, created_at')
          .eq('users_id', user.id)
          .eq('tipo', 'ubicacion')
          .order('created_at', ascending: false);
      loadingStep = 'solicitudes de ubicación recibidas';
      final receivedLocationRequests = await _client
          .from('notificaciones_solicitudes')
          .select('id, users_id, target_id, estado, created_at')
          .eq('target_id', user.id)
          .eq('tipo', 'ubicacion')
          .order('created_at', ascending: false);
      loadingStep = 'perfiles de usuarios';
      final profileRows = await _client
          .from('usuarios')
          .select('id, name, email, user_photo')
          .neq('id', user.id);

      if (!mounted) return;
      setState(() {
        _notifications = alerts
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList();
        _sentRequests = sentRequests
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList();
        _receivedRequests = receivedRequests
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList();
        _sentLocationRequests = sentLocationRequests
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList();
        _receivedLocationRequests = receivedLocationRequests
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList();
        _profiles = {
          for (final row in profileRows)
            row['id'].toString(): Map<String, dynamic>.from(row),
        };
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      debugPrint(
        'No se pudieron cargar las notificaciones '
        '(${error.code ?? 'Supabase'}): ${error.message}; '
        'detalle: ${error.details}; sugerencia: ${error.hint}',
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError =
            'No se pudieron cargar $loadingStep '
            '(${error.code ?? 'Supabase'}): ${error.message}'
            '${error.details == null ? '' : '\nDetalle: ${error.details}'}'
            '${error.hint == null ? '' : '\nSugerencia: ${error.hint}'}';
      });
    } catch (error) {
      debugPrint('No se pudieron cargar las notificaciones: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'No se pudieron cargar las notificaciones: $error';
      });
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    final requestId = request['id'].toString();
    if (!_processingRequestIds.add(requestId)) return;
    if (mounted) setState(() {});

    try {
      final usersId = request['users_id'].toString();
      final targetId = request['target_id'].toString();
      final existingFriendship = await _client
          .from('amistades')
          .select('id')
          .eq('users_id', usersId)
          .eq('target_id', targetId)
          .limit(1)
          .maybeSingle();
      final existingReverseFriendship = existingFriendship == null
          ? await _client
                .from('amistades')
                .select('id')
                .eq('users_id', targetId)
                .eq('target_id', usersId)
                .limit(1)
                .maybeSingle()
          : null;

      if (existingFriendship == null && existingReverseFriendship == null) {
        await _client.from('amistades').insert({
          'users_id': request['users_id'],
          'target_id': request['target_id'],
        });
      }
      await _deleteRequestRows(request);
      if (!mounted) return;
      await _loadNotifications();
      _showMessage('Solicitud aceptada');
    } on PostgrestException catch (error) {
      _showMessage('No se pudo aceptar la solicitud: ${error.message}');
    } catch (error) {
      _showMessage('No se pudo aceptar la solicitud: $error');
    } finally {
      _processingRequestIds.remove(requestId);
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteRequest(Map<String, dynamic> request) async {
    try {
      await _deleteRequestRows(request);
      if (!mounted) return;
      await _loadNotifications();
      _showMessage('Solicitud eliminada');
    } on PostgrestException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    try {
      await _deleteRequestRows(request);

      if (!mounted) return;
      await _loadNotifications();
      _showMessage('Solicitud rechazada');
    } on PostgrestException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  Future<void> _deleteRequestRows(Map<String, dynamic> request) async {
    final deleted = await _client
        .from('notificaciones_solicitudes')
        .delete()
        .eq('id', request['id'])
        .select('id');

    if (deleted.isEmpty) {
      return;
    }
  }

  Future<void> _respondToLocationRequest(
    Map<String, dynamic> request, {
    required bool accept,
  }) async {
    final requestId = request['id'].toString();
    if (!_processingRequestIds.add('location-$requestId')) return;
    if (mounted) setState(() {});

    try {
      await _client.rpc(
        'responder_solicitud_ubicacion',
        params: {
          'p_request_id': (request['id'] as num).toInt(),
          'p_accept': accept,
        },
      );
      if (!mounted) return;
      await _loadNotifications();
      _showMessage(
        accept
            ? 'Solicitud aceptada. Verás su ubicación en Espectador cuando la comparta.'
            : 'Solicitud de ubicación rechazada.',
      );
    } on PostgrestException catch (error) {
      _showMessage('No se pudo responder la solicitud: ${error.message}');
    } catch (error) {
      _showMessage('No se pudo responder la solicitud: $error');
    } finally {
      _processingRequestIds.remove('location-$requestId');
      if (mounted) setState(() {});
    }
  }

  Future<void> _deleteLocationRequest(Map<String, dynamic> request) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('notificaciones_solicitudes')
          .delete()
          .eq('id', request['id'])
          .eq('users_id', userId)
          .eq('tipo', 'ubicacion');
      if (!mounted) return;
      await _loadNotifications();
      _showMessage('Solicitud eliminada.');
    } on PostgrestException catch (error) {
      _showMessage('No se pudo eliminar la solicitud: ${error.message}');
    } catch (error) {
      _showMessage('No se pudo eliminar la solicitud: $error');
    }
  }

  Future<void> _markGlobalNotificationAsRead(
    Map<String, dynamic> notification,
  ) async {
    if (notification['status'] == true) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('notificaciones_alertas')
          .update({'status': true})
          .eq('id', notification['id'])
          .eq('espectador_id', userId);
      if (!mounted) return;
      setState(() => notification['status'] = true);
    } on PostgrestException catch (error) {
      _showMessage('No se pudo marcar el aviso como visto: ${error.message}');
    } catch (error) {
      _showMessage('No se pudo marcar el aviso como visto: $error');
    }
  }

  Future<void> _deleteGlobalNotification(
    Map<String, dynamic> notification,
  ) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    try {
      await _client
          .from('notificaciones_alertas')
          .delete()
          .eq('id', notification['id'])
          .eq('espectador_id', userId);
      if (!mounted) return;
      setState(() => _notifications.remove(notification));
    } on PostgrestException catch (error) {
      _showMessage('No se pudo eliminar el aviso: ${error.message}');
    } catch (error) {
      _showMessage('No se pudo eliminar el aviso: $error');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _dateLabel(dynamic value) {
    if (value == null) return '';
    final date = DateTime.tryParse(value.toString())?.toLocal();
    if (date == null) return value.toString();
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: _isLoading
          ? const ContentStateView(isLoading: true)
          : _loadError != null
          ? ContentStateView(message: _loadError!, onRetry: _loadNotifications)
          : _notifications.isEmpty &&
                _sentRequests.isEmpty &&
                _receivedRequests.isEmpty &&
                _sentLocationRequests.isEmpty &&
                _receivedLocationRequests.isEmpty
          ? const ContentStateView(message: 'No tienes notificaciones.')
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount:
                    _sentRequests.length +
                    _receivedRequests.length +
                    _sentLocationRequests.length +
                    _receivedLocationRequests.length +
                    _notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index < _receivedRequests.length) {
                    final request = _receivedRequests[index];
                    final isProcessing = _processingRequestIds.contains(
                      request['id'].toString(),
                    );
                    final sender = _profiles[request['users_id'].toString()];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_add_alt_1),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${sender?['name'] ?? sender?['email'] ?? 'Usuario'} '
                                    'te envió una solicitud',
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text('Solicitud recibida'),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: isProcessing
                                      ? null
                                      : () => _acceptRequest(request),
                                  icon: isProcessing
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.check, size: 16),
                                  label: Text(
                                    isProcessing ? 'Procesando...' : 'Aceptar',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: isProcessing
                                      ? null
                                      : () => _rejectRequest(request),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Rechazar'),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  onPressed: isProcessing
                                      ? null
                                      : () => _deleteRequest(request),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final receivedLocationIndex =
                      index - _receivedRequests.length;
                  if (receivedLocationIndex <
                      _receivedLocationRequests.length) {
                    final request =
                        _receivedLocationRequests[receivedLocationIndex];
                    final requestId = 'location-${request['id']}';
                    final status =
                        request['estado']?.toString().toLowerCase() ??
                        'pendiente';
                    final isPending =
                        status == 'pendiente' || status == 'pending';
                    final isProcessing = _processingRequestIds.contains(
                      requestId,
                    );
                    final requester = _profiles[request['users_id'].toString()];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on_outlined),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${requester?['name'] ?? requester?['email'] ?? 'Usuario'} '
                                    'solicita ver tu ubicación',
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(switch (status) {
                              'pendiente' || 'pending' =>
                                'Al aceptar, podrá ver tu ubicación cuando '
                                    'la compartas durante una grabación.',
                              'aceptada' || 'accepted' => 'Solicitud aceptada.',
                              'rechazada' ||
                              'rejected' => 'Solicitud rechazada.',
                              _ => 'Estado de la solicitud: $status',
                            }),
                            if (isPending) ...[
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: [
                                  TextButton.icon(
                                    onPressed: isProcessing
                                        ? null
                                        : () => _respondToLocationRequest(
                                            request,
                                            accept: true,
                                          ),
                                    icon: isProcessing
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Icon(Icons.check, size: 16),
                                    label: Text(
                                      isProcessing
                                          ? 'Procesando...'
                                          : 'Aceptar',
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: isProcessing
                                        ? null
                                        : () => _respondToLocationRequest(
                                            request,
                                            accept: false,
                                          ),
                                    icon: const Icon(Icons.close, size: 16),
                                    label: const Text('Rechazar'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }

                  final sentFriendIndex =
                      index -
                      _receivedRequests.length -
                      _receivedLocationRequests.length;
                  final sentIndex = sentFriendIndex;
                  if (sentIndex < _sentRequests.length) {
                    final request = _sentRequests[sentIndex];
                    final receiver = _profiles[request['target_id'].toString()];
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.outgoing_mail),
                        title: Text(
                          'Solicitud enviada a '
                          '${receiver?['name'] ?? receiver?['email'] ?? 'Usuario'}',
                        ),
                        subtitle: const Text('Pendiente de respuesta'),
                        trailing: IconButton(
                          tooltip: 'Eliminar',
                          onPressed: () => _deleteRequest(request),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    );
                  }

                  final sentLocationIndex = sentIndex - _sentRequests.length;
                  if (sentLocationIndex < _sentLocationRequests.length) {
                    final request = _sentLocationRequests[sentLocationIndex];
                    final receiver = _profiles[request['target_id'].toString()];
                    final status = request['estado']?.toString();
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        leading: const Icon(Icons.location_searching),
                        title: Text(
                          'Solicitud para ver la ubicación de '
                          '${receiver?['name'] ?? receiver?['email'] ?? 'Usuario'}',
                        ),
                        subtitle: Text(switch (status) {
                          'aceptada' => 'Aceptada',
                          'rechazada' => 'Rechazada',
                          _ => 'Pendiente de respuesta',
                        }),
                        trailing: status == 'aceptada'
                            ? null
                            : IconButton(
                                tooltip: 'Eliminar',
                                onPressed: () =>
                                    _deleteLocationRequest(request),
                                icon: const Icon(Icons.delete_outline),
                              ),
                      ),
                    );
                  }

                  final notification =
                      _notifications[index -
                          _receivedRequests.length -
                          _receivedLocationRequests.length -
                          _sentRequests.length -
                          _sentLocationRequests.length];
                  final isUnread = notification['status'] != true;
                  return Card(
                    margin: EdgeInsets.zero,
                    color: isUnread ? colors.primaryContainer : null,
                    child: ListTile(
                      leading: Icon(
                        isUnread
                            ? Icons.notifications_active_outlined
                            : Icons.notifications_none_outlined,
                      ),
                      title: Text(
                        notification['message']?.toString() ??
                            'Nueva notificación',
                        style: TextStyle(
                          fontWeight: isUnread
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      subtitle: Text(
                        '${notification['type'] ?? 'general'} · '
                        '${_dateLabel(notification['created_at'])}',
                      ),
                      onTap: () => _markGlobalNotificationAsRead(notification),
                      trailing: IconButton(
                        tooltip: 'Eliminar',
                        onPressed: () =>
                            _deleteGlobalNotification(notification),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

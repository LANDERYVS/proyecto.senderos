import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  Map<String, Map<String, dynamic>> _profiles = const {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final rows = await _client
          .from('notificaciones')
          .select('id, type, message, status, created_at')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);
      final sentRequests = await _client
          .from('solicitudes')
          .select('id, users_id, target_id, created_at')
          .eq('users_id', user.id)
          .order('created_at', ascending: false);
      final receivedRequests = await _client
          .from('solicitudes')
          .select('id, users_id, target_id, created_at')
          .eq('target_id', user.id)
          .order('created_at', ascending: false);
      final profileRows = await _client
          .from('usuarios')
          .select('id, name, email, user_photo')
          .neq('id', user.id);

      if (!mounted) return;
      setState(() {
        _notifications = rows
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList();
        _sentRequests = sentRequests
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList();
        _receivedRequests = receivedRequests
            .map<Map<String, dynamic>>((row) => Map<String, dynamic>.from(row))
            .toList();
        _profiles = {
          for (final row in profileRows)
            row['id'].toString(): Map<String, dynamic>.from(row),
        };
        _isLoading = false;
      });
    } on PostgrestException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  Future<void> _markAsRead(Map<String, dynamic> notification) async {
    if (notification['status'] == true) return;

    try {
      await _client
          .from('notificaciones')
          .update({'status': true})
          .eq('id', notification['id']);
      if (!mounted) return;
      setState(() => notification['status'] = true);
    } on PostgrestException catch (_) {
      return;
    }
  }

  Future<void> _markAllAsRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      await _client
          .from('notificaciones')
          .update({'status': true})
          .eq('user_id', user.id)
          .eq('status', false);
      if (!mounted) return;
      setState(() {
        for (final notification in _notifications) {
          notification['status'] = true;
        }
      });
    } on PostgrestException catch (_) {
      return;
    }
  }

  Future<void> _acceptRequest(Map<String, dynamic> request) async {
    try {
      await _client.from('amistades').insert({
        'users_id': request['users_id'],
        'target_id': request['target_id'],
      });
      await _deleteRequestRows(request);
      await _removeRequestNotification(request);
      if (!mounted) return;
      await _loadNotifications();
      _showMessage('Solicitud aceptada');
    } on PostgrestException catch (_) {
      return;
    } catch (_) {
      return;
    }
  }

  Future<void> _deleteRequest(Map<String, dynamic> request) async {
    try {
      await _deleteRequestRows(request);
      if (_isReceivedRequest(request)) {
        await _removeRequestNotification(request);
      }
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
      await _removeRequestNotification(request);

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
        .from('solicitudes')
        .delete()
        .eq('id', request['id'])
        .select('id');

    if (deleted.isEmpty) {
      return;
    }
  }

  bool _isReceivedRequest(Map<String, dynamic> request) {
    final user = _client.auth.currentUser;
    return user != null && request['target_id'].toString() == user.id;
  }

  Future<void> _removeRequestNotification(Map<String, dynamic> request) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    final sender = _profiles[request['users_id'].toString()];
    final senderName =
        sender?['name']?.toString() ??
        sender?['email']?.toString() ??
        'Usuario';
    await _client
        .from('notificaciones')
        .delete()
        .eq('user_id', user.id)
        .eq('type', 'friend_request')
        .eq('message', '$senderName te ha enviado una solicitud de amistad.');
  }

  Future<void> _deleteNotification(Map<String, dynamic> notification) async {
    try {
      await _client
          .from('notificaciones')
          .delete()
          .eq('id', notification['id']);
      if (!mounted) return;
      setState(() => _notifications.remove(notification));
    } on PostgrestException catch (_) {
      return;
    } catch (_) {
      return;
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
    final unreadCount = _notifications
        .where((notification) => notification['status'] != true)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: _markAllAsRead,
              child: const Text('Marcar todas'),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notifications.isEmpty &&
                _sentRequests.isEmpty &&
                _receivedRequests.isEmpty
          ? const Center(child: Text('No tienes notificaciones.'))
          : RefreshIndicator(
              onRefresh: _loadNotifications,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount:
                    _sentRequests.length +
                    _receivedRequests.length +
                    _notifications.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  if (index < _receivedRequests.length) {
                    final request = _receivedRequests[index];
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
                                  onPressed: () => _acceptRequest(request),
                                  icon: const Icon(Icons.check, size: 16),
                                  label: const Text('Aceptar'),
                                ),
                                TextButton.icon(
                                  onPressed: () => _rejectRequest(request),
                                  icon: const Icon(Icons.close, size: 16),
                                  label: const Text('Rechazar'),
                                ),
                                IconButton(
                                  tooltip: 'Eliminar',
                                  onPressed: () => _deleteRequest(request),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final sentIndex = index - _receivedRequests.length;
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

                  final notification =
                      _notifications[index -
                          _receivedRequests.length -
                          _sentRequests.length];
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
                      onTap: () => _markAsRead(notification),
                      trailing: IconButton(
                        tooltip: 'Eliminar',
                        onPressed: () => _deleteNotification(notification),
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

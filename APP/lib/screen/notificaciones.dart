import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/content_state_view.dart';

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
  final Set<String> _processingRequestIds = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint('No se cargaron notificaciones: no hay una sesión iniciada.');
      return;
    }

    try {
      final rows = await _client
          .from('notificaciones_alertas')
          .select('id, type, message, status, created_at')
          .order('created_at', ascending: false);
      final sentRequests = await _client
          .from('notificaciones_solicitudes')
          .select('id, users_id, target_id, created_at')
          .eq('users_id', user.id)
          .order('created_at', ascending: false);
      final receivedRequests = await _client
          .from('notificaciones_solicitudes')
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
    } on PostgrestException catch (error) {
      debugPrint(
        'No se pudieron cargar las notificaciones '
        '(${error.code ?? 'Supabase'}): ${error.message}; '
        'detalle: ${error.details}; sugerencia: ${error.hint}',
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('No se pudieron cargar las notificaciones: $error');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
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
          : _notifications.isEmpty &&
                _sentRequests.isEmpty &&
                _receivedRequests.isEmpty
          ? const ContentStateView(message: 'No tienes notificaciones.')
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
                    ),
                  );
                },
              ),
            ),
    );
  }
}

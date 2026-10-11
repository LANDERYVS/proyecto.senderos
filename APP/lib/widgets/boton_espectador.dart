import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/compartir_ubicacion.dart';
import 'avatar_usuario.dart';

/*
 * Botón para iniciar o detener el uso compartido de ubicación con un amigo.
 * También permite elegir a quién solicitarle ubicación y espera la aprobación
 * de solicitudes pendientes.
 */
class BotonEspectador extends StatefulWidget {
  const BotonEspectador({
    super.key,
    required this.sharingService,
    required this.getCurrentLocation,
    required this.heroTag,
    this.senderoId,
    this.onSharingChanged,
  });

  final CompartirUbicacionService sharingService;
  final Future<LatLng?> Function() getCurrentLocation;
  final String heroTag;
  final int? senderoId;
  final VoidCallback? onSharingChanged;

  @override
  State<BotonEspectador> createState() =>
      _BotonEspectadorState();
}

class _BotonEspectadorState extends State<BotonEspectador> {
  // Revisa periódicamente si el amigo aceptó la solicitud.
  Timer? _approvalTimer;
  // Evita continuar revisando después de aceptar o abandonar el flujo.
  bool _waitingForApproval = false;
  // Impide que dos consultas de aprobación se ejecuten al mismo tiempo.
  bool _checkingApproval = false;

  @override
  void dispose() {
    // Detiene el temporizador al cerrar el widget para que no siga consultando.
    _approvalTimer?.cancel();
    super.dispose();
  }

  // Carga los amigos y muestra sus solicitudes o el estado de ubicación compartida.
  Future<void> _chooseFriend() async {
    try {
      final friends = await widget.sharingService.loadFriends();
      if (friends.isEmpty) {
        _showMessage('Primero agrega un amigo desde Comunidad.');
        return;
      }
      if (!mounted) return;

      final friend = await showModalBottomSheet<ShareFriend>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              const ListTile(
                title: Text(
                  'Ubicación de amigos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  'Solicita acceso o comparte tu ubicación con quien te la pidió.',
                ),
              ),
              // Cada fila muestra el perfil del amigo y el estado de la solicitud.
              for (final friend in friends)
                ListTile(
                  leading: DefaultUserAvatar(
                    radius: 20,
                    imageUrl: friend.photoUrl,
                  ),
                  title: Text(friend.name),
                  subtitle: friend.email.isEmpty ? null : Text(friend.email),
                  trailing: _buildFriendAction(friend),
                  onTap: () => Navigator.pop(context, friend),
                ),
            ],
          ),
        ),
      );
      if (friend != null) {
        // Decide qué hacer según el estado de la solicitud entre ambos usuarios.
        if (friend.requestToFriendStatus == 'aceptada') {
          await _requestLocation(friend);
        } else if (friend.requestFromFriendStatus == 'aceptada') {
          _showMessage(
            'Aceptaste la solicitud de ${friend.name}. Su ubicación '
            'aparecerá aquí cuando comience a compartirla.',
          );
        } else if (friend.requestToFriendStatus == 'pendiente') {
          _watchForApproval(friend.id);
          _showMessage('Tu solicitud para ${friend.name} sigue pendiente.');
        } else if (friend.requestFromFriendStatus == 'pendiente') {
          _showMessage(
            'Revisa tus notificaciones para responder la solicitud de '
            '${friend.name}.',
          );
        } else {
          await _requestLocation(friend);
        }
      }
    } on StateError catch (error) {
      _showMessage(error.message);
    } on Exception catch (error) {
      _showMessage('No se pudo cargar la lista de amigos: $error');
    }
  }

  // Elige el texto o icono de cada amigo según el estado de sus solicitudes.
  Widget _buildFriendAction(ShareFriend friend) {
    if (friend.requestFromFriendStatus == 'aceptada') {
      return const Icon(Icons.visibility);
    }
    if (friend.requestToFriendStatus == 'aceptada') {
      return const Text('Solicitar de nuevo');
    }
    if (friend.requestToFriendStatus == 'pendiente') {
      return const Text('Pendiente');
    }
    if (friend.requestFromFriendStatus == 'pendiente') {
      return const Icon(Icons.notifications_outlined);
    }
    return const Icon(Icons.chevron_right);
  }

  // Envía una solicitud para poder ver la ubicación del amigo.
  Future<void> _requestLocation(ShareFriend friend) async {
    try {
      await widget.sharingService.requestLocation(friend);
      _watchForApproval(friend.id);
      _showMessage('Solicitud enviada a ${friend.name}.');
    } on StateError catch (error) {
      _showMessage(error.message);
    } on Exception catch (error) {
      _showMessage('No se pudo enviar la solicitud: $error');
    }
  }

  // Inicia una revisión cada cinco segundos hasta que el amigo responda.
  void _watchForApproval(String friendId) {
    _waitingForApproval = true;
    _approvalTimer?.cancel();
    _approvalTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkApproval(friendId),
    );
  }

  // Consulta si el amigo aceptó; al confirmarlo, empieza a compartir ubicación.
  Future<void> _checkApproval(String friendId) async {
    if (!mounted || !_waitingForApproval || _checkingApproval) return;
    _checkingApproval = true;
    try {
      final friends = await widget.sharingService.loadFriends();
      if (!mounted || !_waitingForApproval) return;
      ShareFriend? approvedFriend;
      // Busca al amigo solicitado y confirma que su respuesta sea afirmativa.
      for (final friend in friends) {
        if (friend.id == friendId &&
            friend.requestToFriendStatus == 'aceptada') {
          approvedFriend = friend;
          break;
        }
      }
      if (approvedFriend != null) {
        await _startSharing(approvedFriend);
      }
    } on Exception catch (error) {
      debugPrint('No se pudo comprobar la aprobación de ubicación: $error');
    } finally {
      // Permite que la siguiente consulta periódica pueda ejecutarse.
      _checkingApproval = false;
    }
  }

  // Empieza a compartir la ubicación actual cuando el GPS está disponible.
  Future<void> _startSharing(ShareFriend friend) async {
    try {
      if (await widget.getCurrentLocation() == null) {
        _showMessage('Esperá a que se obtenga tu ubicación GPS.');
        return;
      }
      await widget.sharingService.startSharing(
        friend,
        _publishCurrentLocation,
        senderoId: widget.senderoId,
      );
      // La solicitud ya fue atendida; detiene las revisiones periódicas.
      _waitingForApproval = false;
      _approvalTimer?.cancel();
      _approvalTimer = null;
      if (!mounted) return;
      setState(() {});
      _showMessage('Ubicación compartida con ${friend.name}.');
    } on StateError catch (error) {
      _showMessage(error.message);
    } on Exception catch (error) {
      _showMessage('No se pudo compartir la ubicación: $error');
    } finally {
      // Avisa a la pantalla contenedora para que actualice el estado relacionado.
      widget.onSharingChanged?.call();
    }
  }

  // Obtiene la ubicación más reciente y la envía al servicio de compartición.
  Future<void> _publishCurrentLocation() async {
    final location = await widget.getCurrentLocation();
    if (location == null) {
      throw StateError('Todavía no hay una ubicación GPS disponible.');
    }
    await widget.sharingService.publishLocation(location);
  }

  // Detiene el envío de ubicación y actualiza el estado visual del botón.
  Future<void> _stopSharing() async {
    try {
      await widget.sharingService.stopSharing();
      if (!mounted) return;
      setState(() {});
      _showMessage('Dejaste de compartir tu ubicación.');
    } on Exception catch (error) {
      if (mounted) setState(() {});
      _showMessage('No se pudo dejar de compartir la ubicación: $error');
    } finally {
      // Notifica a la pantalla contenedora que cambió el estado de compartición.
      widget.onSharingChanged?.call();
    }
  }

  // Muestra mensajes breves de éxito o error en la parte inferior de la pantalla.
  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isSharing = widget.sharingService.sharingFriend != null;
    final colorScheme = Theme.of(context).colorScheme;
    // El botón cambia su icono, color y acción según se esté compartiendo o no.
    return FloatingActionButton.small(
      heroTag: widget.heroTag,
      tooltip: isSharing
          ? 'Dejar de compartir ubicación'
          : 'Solicitar o compartir ubicación',
      backgroundColor: isSharing ? colorScheme.primary : Colors.white,
      foregroundColor: isSharing ? Colors.white : Colors.black87,
      onPressed: isSharing ? _stopSharing : _chooseFriend,
      child: Icon(isSharing ? Icons.visibility : Icons.visibility_off),
    );
  }
}

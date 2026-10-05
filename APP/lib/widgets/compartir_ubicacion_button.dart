import 'dart:async';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../services/compartir_ubicacion.dart';
import 'default_user_avatar.dart';

class CompartirUbicacionButton extends StatefulWidget {
  const CompartirUbicacionButton({
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
  State<CompartirUbicacionButton> createState() =>
      _CompartirUbicacionButtonState();
}

class _CompartirUbicacionButtonState extends State<CompartirUbicacionButton> {
  Timer? _approvalTimer;
  bool _waitingForApproval = false;
  bool _checkingApproval = false;

  @override
  void dispose() {
    _approvalTimer?.cancel();
    super.dispose();
  }

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
        if (friend.requestToFriendStatus == 'aceptada') {
          await _startSharing(friend);
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

  Widget _buildFriendAction(ShareFriend friend) {
    if (friend.requestFromFriendStatus == 'aceptada') {
      return const Icon(Icons.location_on_outlined);
    }
    if (friend.requestToFriendStatus == 'aceptada') {
      return const Text('Aceptada');
    }
    if (friend.requestToFriendStatus == 'pendiente') {
      return const Text('Pendiente');
    }
    if (friend.requestFromFriendStatus == 'pendiente') {
      return const Icon(Icons.notifications_outlined);
    }
    return const Icon(Icons.chevron_right);
  }

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

  void _watchForApproval(String friendId) {
    _waitingForApproval = true;
    _approvalTimer?.cancel();
    _approvalTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkApproval(friendId),
    );
  }

  Future<void> _checkApproval(String friendId) async {
    if (!mounted || !_waitingForApproval || _checkingApproval) return;
    _checkingApproval = true;
    try {
      final friends = await widget.sharingService.loadFriends();
      if (!mounted || !_waitingForApproval) return;
      ShareFriend? approvedFriend;
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
      _checkingApproval = false;
    }
  }

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
      widget.onSharingChanged?.call();
    }
  }

  Future<void> _publishCurrentLocation() async {
    final location = await widget.getCurrentLocation();
    if (location == null) {
      throw StateError('Todavía no hay una ubicación GPS disponible.');
    }
    await widget.sharingService.publishLocation(location);
  }

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
      widget.onSharingChanged?.call();
    }
  }

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
    return FloatingActionButton.small(
      heroTag: widget.heroTag,
      tooltip: isSharing
          ? 'Dejar de compartir ubicación'
          : 'Solicitar o compartir ubicación',
      backgroundColor: isSharing ? colorScheme.primary : Colors.white,
      foregroundColor: isSharing ? Colors.white : Colors.black87,
      onPressed: isSharing ? _stopSharing : _chooseFriend,
      child: Icon(isSharing ? Icons.location_on : Icons.location_on_outlined),
    );
  }
}

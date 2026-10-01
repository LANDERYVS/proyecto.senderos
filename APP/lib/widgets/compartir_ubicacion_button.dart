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
  });

  final CompartirUbicacionService sharingService;
  final Future<LatLng?> Function() getCurrentLocation;
  final String heroTag;
  final int? senderoId;

  @override
  State<CompartirUbicacionButton> createState() =>
      _CompartirUbicacionButtonState();
}

class _CompartirUbicacionButtonState extends State<CompartirUbicacionButton> {
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
                  'Compartir mi ubicación',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text('Elige un amigo para verla en su mapa.'),
              ),
              for (final friend in friends)
                ListTile(
                  leading: DefaultUserAvatar(
                    radius: 20,
                    imageUrl: friend.photoUrl,
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
      if (friend != null) await _startSharing(friend);
    } on Exception {
      _showMessage('No hay conexión a internet.');
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
      if (!mounted) return;
      setState(() {});
      _showMessage('Ubicación compartida con ${friend.name}.');
    } on Exception {
      _showMessage('No hay conexión a internet.');
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
    } on Exception {
      if (mounted) setState(() {});
      _showMessage('No hay conexión a internet.');
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
          : 'Compartir ubicación',
      backgroundColor: isSharing ? colorScheme.primary : Colors.white,
      foregroundColor: isSharing ? Colors.white : Colors.black87,
      onPressed: isSharing ? _stopSharing : _chooseFriend,
      child: Icon(isSharing ? Icons.location_on : Icons.location_on_outlined),
    );
  }
}

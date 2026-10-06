import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/explore_trail.dart';

class ShareFriend {
  const ShareFriend({
    required this.id,
    required this.name,
    required this.email,
    required this.friendshipId,
    this.phone,
    this.photoUrl,
    this.location,
    this.requestToFriendStatus,
    this.requestFromFriendStatus,
  });

  factory ShareFriend.fromMap(
    Map<String, dynamic> profile, {
    required int friendshipId,
    LatLng? location,
    String? requestToFriendStatus,
    String? requestFromFriendStatus,
  }) {
    final name = profile['name']?.toString().trim();
    final email = profile['email']?.toString().trim() ?? '';
    final phone = profile['telefono']?.toString().trim();
    return ShareFriend(
      id: profile['id'].toString(),
      name: name?.isNotEmpty == true ? name! : email,
      email: email,
      friendshipId: friendshipId,
      phone: phone?.isNotEmpty == true ? phone : null,
      photoUrl: ExploreTrail.publicR2Url(profile['user_photo']?.toString()),
      location: location,
      requestToFriendStatus: requestToFriendStatus,
      requestFromFriendStatus: requestFromFriendStatus,
    );
  }

  final String id;
  final String name;
  final String email;
  final int friendshipId;
  final String? phone;
  final String? photoUrl;
  final LatLng? location;
  final String? requestToFriendStatus;
  final String? requestFromFriendStatus;

  ShareFriend withLocation(LatLng? value) => ShareFriend(
    id: id,
    name: name,
    email: email,
    friendshipId: friendshipId,
    phone: phone,
    photoUrl: photoUrl,
    location: value,
    requestToFriendStatus: requestToFriendStatus,
    requestFromFriendStatus: requestFromFriendStatus,
  );
}

class ObservedTrailGroup {
  const ObservedTrailGroup({
    required this.trailId,
    required this.name,
    required this.observers,
    this.photoUrl,
    this.gpxUrl,
    this.isLive = false,
  });

  final int trailId;
  final String name;
  final String? photoUrl;
  final String? gpxUrl;
  final List<ShareFriend> observers;
  final bool isLive;

  ObservedTrailGroup withObservers(List<ShareFriend> value) =>
      ObservedTrailGroup(
        trailId: trailId,
        name: name,
        photoUrl: photoUrl,
        gpxUrl: gpxUrl,
        observers: value,
        isLive: isLive,
      );
}

class CompartirUbicacionService {
  CompartirUbicacionService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  Timer? _sharingTimer;
  ShareFriend? _sharingFriend;
  int? _sharingRelationId;

  ShareFriend? get sharingFriend => _sharingFriend;

  Future<List<ShareFriend>> loadFriends() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return [];

    final friendships = await _client
        .from('amistades')
        .select('id, users_id, target_id')
        .or('users_id.eq.${currentUser.id},target_id.eq.${currentUser.id}');
    final friendshipIdsByFriend = <String, int>{};
    final friendIds = friendships
        .map<String>((friendship) {
          final usersId = friendship['users_id'].toString();
          final targetId = friendship['target_id'].toString();
          final friendId = usersId == currentUser.id ? targetId : usersId;
          friendshipIdsByFriend[friendId] = (friendship['id'] as num).toInt();
          return friendId;
        })
        .toSet()
        .toList();

    if (friendIds.isEmpty) return [];

    final locationRequests = await _client
        .from('notificaciones_espectador')
        .select('user_id, target_id, estado, created_at')
        .or('user_id.eq.${currentUser.id},target_id.eq.${currentUser.id}');
    locationRequests.sort((a, b) {
      final aCreatedAt =
          DateTime.tryParse(a['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bCreatedAt =
          DateTime.tryParse(b['created_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bCreatedAt.compareTo(aCreatedAt);
    });
    final requestStatusesByFriend = <String, Map<String, String>>{};
    for (final request in locationRequests) {
      final requesterId = request['user_id'].toString();
      final targetId = request['target_id'].toString();
      final friendId = requesterId == currentUser.id ? targetId : requesterId;
      final statuses = requestStatusesByFriend.putIfAbsent(
        friendId,
        () => <String, String>{},
      );
      final direction = requesterId == currentUser.id ? 'toFriend' : 'fromFriend';
      statuses.putIfAbsent(direction, () => request['estado'].toString());
    }

    final profiles = await _client
        .from('usuarios')
        .select('id, name, email, telefono, user_photo')
        .inFilter('id', friendIds);
    return profiles.map<ShareFriend>((profile) {
      return ShareFriend.fromMap(
        profile,
        friendshipId: friendshipIdsByFriend[profile['id'].toString()]!,
        requestToFriendStatus:
            requestStatusesByFriend[profile['id'].toString()]?['toFriend'],
        requestFromFriendStatus:
            requestStatusesByFriend[profile['id'].toString()]?['fromFriend'],
      );
    }).toList();
  }

  Future<void> requestLocation(ShareFriend friend) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('Inicia sesión para solicitar una ubicación.');
    }

    final existingRequests = await _client
        .from('notificaciones_espectador')
        .select('id, estado')
        .eq('user_id', currentUser.id)
        .eq('target_id', friend.id);
    if (existingRequests.any((request) => request['estado'] == 'pendiente')) {
      throw StateError(
        'Ya tienes una solicitud pendiente para ${friend.name}.',
      );
    }

    if (existingRequests.isNotEmpty) {
      final deleted = await _client
          .from('notificaciones_espectador')
          .delete()
          .eq('user_id', currentUser.id)
          .eq('target_id', friend.id)
          .select('id');
      if (deleted.length != existingRequests.length) {
        throw StateError(
          'No se pudo restablecer la solicitud anterior para ${friend.name}.',
        );
      }
    }
    await _client.from('notificaciones_espectador').insert({
      'user_id': currentUser.id,
      'target_id': friend.id,
      'estado': 'pendiente',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<List<ObservedTrailGroup>> loadObservedTrails() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return [];

    final relations = await _client
        .from('relaciones_espectadores')
        .select('amistad, sendero_id')
        .eq('espectador_id', currentUser.id)
        .eq('enabled', true);
    final trailIdsByFriendship = <int, int>{};
    final liveFriendshipIds = <int>{};
    for (final relation in relations) {
      final friendshipId = (relation['amistad'] as num?)?.toInt();
      final trailId = (relation['sendero_id'] as num?)?.toInt();
      if (friendshipId == null) continue;
      if (trailId == null) {
        liveFriendshipIds.add(friendshipId);
      } else {
        trailIdsByFriendship[friendshipId] = trailId;
      }
    }
    final friendshipIds = {
      ...trailIdsByFriendship.keys,
      ...liveFriendshipIds,
    }.toList();
    if (friendshipIds.isEmpty) return [];

    final friendships = await _client
        .from('amistades')
        .select('id, users_id, target_id')
        .inFilter('id', friendshipIds);
    final friendIdsByFriendship = <int, String>{};
    for (final friendship in friendships) {
      final usersId = friendship['users_id'].toString();
      final targetId = friendship['target_id'].toString();
      final friendId = usersId == currentUser.id ? targetId : usersId;
      friendIdsByFriendship[(friendship['id'] as num).toInt()] = friendId;
    }
    if (friendIdsByFriendship.isEmpty) return [];

    final friendIds = friendIdsByFriendship.values.toSet().toList();
    final trailIds = trailIdsByFriendship.values.toSet().toList();
    final profiles = await _client
        .from('usuarios')
        .select('id, name, email, telefono, user_photo')
        .inFilter('id', friendIds);
    final trails = trailIds.isEmpty
        ? <Map<String, dynamic>>[]
        : await _client
              .from('senderos')
              .select('id, sendero_nick, foto_sendero, gpx_key')
              .inFilter('id', trailIds);
    final locations = await loadLocations(friendIds);

    final profilesById = {
      for (final profile in profiles) profile['id'].toString(): profile,
    };
    final observersByTrail = <int, List<ShareFriend>>{};
    for (final entry in trailIdsByFriendship.entries) {
      final friendId = friendIdsByFriendship[entry.key];
      final profile = friendId == null ? null : profilesById[friendId];
      if (friendId == null || profile == null) continue;
      final friendship = friendships.firstWhere(
        (row) => (row['id'] as num).toInt() == entry.key,
      );
      observersByTrail
          .putIfAbsent(entry.value, () => [])
          .add(
            ShareFriend.fromMap(
              profile,
              friendshipId: (friendship['id'] as num).toInt(),
              location: locations[friendId],
            ),
          );
    }

    final trailGroups = trails
        .map<ObservedTrailGroup>((trail) {
          final trailId = (trail['id'] as num).toInt();
          final name = trail['sendero_nick']?.toString().trim();
          return ObservedTrailGroup(
            trailId: trailId,
            name: name?.isNotEmpty == true ? name! : 'Sendero sin nombre',
            photoUrl: ExploreTrail.publicR2Url(
              trail['foto_sendero']?.toString(),
            ),
            gpxUrl: ExploreTrail.publicR2Url(trail['gpx_key']?.toString()),
            observers: observersByTrail[trailId] ?? const [],
          );
        })
        .where((group) => group.observers.isNotEmpty)
        .toList();
    final liveGroups = <ObservedTrailGroup>[];
    for (final friendshipId in liveFriendshipIds) {
      final friendId = friendIdsByFriendship[friendshipId];
      final profile = friendId == null ? null : profilesById[friendId];
      if (friendId == null || profile == null) continue;
      liveGroups.add(
        ObservedTrailGroup(
          trailId: -friendshipId,
          name: 'Grabando trayecto',
          isLive: true,
          observers: [
            ShareFriend.fromMap(
              profile,
              friendshipId: friendshipId,
              location: locations[friendId],
            ),
          ],
        ),
      );
    }

    return [...trailGroups, ...liveGroups];
  }

  Future<Map<String, LatLng>> loadLocations(Iterable<String> userIds) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return {};

    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return {};

    final acceptedRequests = await _client
        .from('notificaciones_espectador')
        .select('user_id')
        .eq('target_id', currentUser.id)
        .eq('estado', 'aceptada')
        .inFilter('user_id', ids);
    final authorizedUserIds = acceptedRequests
        .map<String>((request) => request['user_id'].toString())
        .toSet()
        .toList();
    if (authorizedUserIds.isEmpty) return {};

    final rows = await _client
        .from('ubicacion')
        .select('user_id, lat, long')
        .inFilter('user_id', authorizedUserIds);
    return {
      for (final row in rows)
        row['user_id'].toString(): LatLng(
          (row['lat'] as num).toDouble(),
          (row['long'] as num).toDouble(),
        ),
    };
  }

  Future<void> startSharing(
    ShareFriend friend,
    Future<void> Function() publishLocation, {
    int? senderoId,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return;

    final approvedRequest = await _client
        .from('notificaciones_espectador')
        .select('id')
        .eq('user_id', currentUser.id)
        .eq('target_id', friend.id)
        .eq('estado', 'aceptada')
        .maybeSingle();
    if (approvedRequest == null) {
      throw StateError(
        'B debe aceptar tu solicitud antes de compartir tu ubicación.',
      );
    }

    final existing = await _client
        .from('relaciones_espectadores')
        .select('id')
        .eq('amistad', friend.friendshipId)
        .eq('espectador_id', friend.id)
        .maybeSingle();

    late final int relationId;
    if (existing == null) {
      final inserted = await _client
          .from('relaciones_espectadores')
          .insert({
            'amistad': friend.friendshipId,
            'espectador_id': friend.id,
            'enabled': true,
            'sendero_id': senderoId,
          })
          .select('id')
          .single();
      relationId = (inserted['id'] as num).toInt();
    } else {
      final updated = await _client
          .from('relaciones_espectadores')
          .update({'enabled': true, 'sendero_id': senderoId})
          .eq('id', existing['id'])
          .select('id')
          .maybeSingle();
      if (updated == null) {
        throw StateError('No se pudo activar la relación para compartir.');
      }
      relationId = (existing['id'] as num).toInt();
    }
    _sharingTimer?.cancel();
    _sharingFriend = friend;
    _sharingRelationId = relationId;
    _sharingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => publishLocation(),
    );
    await publishLocation();
  }

  Future<void> publishLocation(LatLng point) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || _sharingFriend == null) return;

    final location = {
      'user_id': currentUser.id,
      'lat': point.latitude,
      'long': point.longitude,
    };
    final existing = await _client
        .from('ubicacion')
        .select('id')
        .eq('user_id', currentUser.id);

    if (existing.isEmpty) {
      await _client.from('ubicacion').insert(location);
    } else {
      await _client
          .from('ubicacion')
          .update(location)
          .eq('user_id', currentUser.id);
    }
  }

  Future<int> sendAlert({
    required String type,
    required String message,
    int? senderoId,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('Inicia sesión para enviar una alerta.');
    }

    final result = await _client.rpc(
      'enviar_alerta_espectadores',
      params: {
        'p_sendero_id': senderoId,
        'p_type': type,
        'p_message': message.trim(),
      },
    );
    if (result is! num) {
      throw StateError('El servidor devolvió una respuesta inválida.');
    }
    return result.toInt();
  }

  Future<void> stopSharing() async {
    final currentUser = _client.auth.currentUser;
    final friend = _sharingFriend;
    final relationId = _sharingRelationId;
    if (currentUser == null || friend == null || relationId == null) return;

    _sharingTimer?.cancel();
    _sharingTimer = null;
    final updated = await _client
        .from('relaciones_espectadores')
        .update({'enabled': false})
        .eq('id', relationId)
        .eq('amistad', friend.friendshipId)
        .eq('espectador_id', friend.id)
        .select('id');
    if (updated.isEmpty) {
      throw StateError(
        'No se pudo finalizar la relación para dejar de compartir.',
      );
    }

    _sharingFriend = null;
    _sharingRelationId = null;

    await _client
        .from('notificaciones_espectador')
        .delete()
        .eq('user_id', currentUser.id)
        .eq('target_id', friend.id)
        .eq('estado', 'aceptada');

    final deleted = await _client
        .from('relaciones_espectadores')
        .delete()
        .eq('id', relationId)
        .eq('amistad', friend.friendshipId)
        .eq('espectador_id', friend.id)
        .eq('enabled', false)
        .select('id');
    if (deleted.isEmpty) {
      throw StateError('La relación se desactivó, pero no se pudo eliminar.');
    }

    _sharingTimer?.cancel();
    _sharingTimer = null;
  }

  void dispose() {
    _sharingTimer?.cancel();
  }
}

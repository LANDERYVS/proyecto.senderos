import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ShareFriend {
  const ShareFriend({
    required this.id,
    required this.name,
    required this.email,
    required this.friendshipId,
  });

  factory ShareFriend.fromMap(
    Map<String, dynamic> profile, {
    required int friendshipId,
  }) {
    final name = profile['name']?.toString().trim();
    final email = profile['email']?.toString().trim() ?? '';
    return ShareFriend(
      id: profile['id'].toString(),
      name: name?.isNotEmpty == true ? name! : email,
      email: email,
      friendshipId: friendshipId,
    );
  }

  final String id;
  final String name;
  final String email;
  final int friendshipId;
}

class CompartirUbicacionService {
  CompartirUbicacionService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  Timer? _sharingTimer;
  ShareFriend? _sharingFriend;

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

    final profiles = await _client
        .from('usuarios')
        .select('id, name, email')
        .inFilter('id', friendIds);
    return profiles.map<ShareFriend>((profile) {
      return ShareFriend.fromMap(
        profile,
        friendshipId: friendshipIdsByFriend[profile['id'].toString()]!,
      );
    }).toList();
  }

  Future<void> startSharing(
    ShareFriend friend,
    Future<void> Function() publishLocation,
  ) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return;

    final existing = await _client
        .from('relaciones_espectadores')
        .select('id')
        .eq('amistad', friend.friendshipId)
        .eq('espectador_id', friend.id)
        .maybeSingle();

    if (existing == null) {
      await _client.from('relaciones_espectadores').insert({
        'amistad': friend.friendshipId,
        'espectador_id': friend.id,
        'enabled': true,
      });
    } else {
      await _client
          .from('relaciones_espectadores')
          .update({'enabled': true})
          .eq('id', existing['id']);
    }
    _sharingTimer?.cancel();
    _sharingFriend = friend;
    _sharingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => publishLocation(),
    );
    await publishLocation();
  }

  Future<void> publishLocation(Marker marker) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || _sharingFriend == null) return;

    final point = marker.point;
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

  Future<void> stopSharing() async {
    final currentUser = _client.auth.currentUser;
    final friend = _sharingFriend;
    if (currentUser == null || friend == null) return;

    await _client
        .from('relaciones_espectadores')
        .update({'enabled': false})
        .eq('amistad', friend.friendshipId)
        .eq('espectador_id', friend.id);
    _sharingTimer?.cancel();
    _sharingTimer = null;
    _sharingFriend = null;
  }

  Future<LatLng?> getFriendLocation(String friendId) async {
    final data = await _client
        .from('ubicacion')
        .select('lat, long')
        .eq('user_id', friendId)
        .maybeSingle();

    if (data == null) return null;

    return LatLng(
      (data['lat'] as num).toDouble(),
      (data['long'] as num).toDouble(),
    );
  }

  void dispose() {
    _sharingTimer?.cancel();
  }
}

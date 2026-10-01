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
    this.photoUrl,
    this.location,
  });

  factory ShareFriend.fromMap(
    Map<String, dynamic> profile, {
    required int friendshipId,
    LatLng? location,
  }) {
    final name = profile['name']?.toString().trim();
    final email = profile['email']?.toString().trim() ?? '';
    return ShareFriend(
      id: profile['id'].toString(),
      name: name?.isNotEmpty == true ? name! : email,
      email: email,
      friendshipId: friendshipId,
      photoUrl: ExploreTrail.publicR2Url(profile['user_photo']?.toString()),
      location: location,
    );
  }

  final String id;
  final String name;
  final String email;
  final int friendshipId;
  final String? photoUrl;
  final LatLng? location;

  ShareFriend withLocation(LatLng? value) => ShareFriend(
    id: id,
    name: name,
    email: email,
    friendshipId: friendshipId,
    photoUrl: photoUrl,
    location: value,
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
        .select('id, name, email, user_photo')
        .inFilter('id', friendIds);
    return profiles.map<ShareFriend>((profile) {
      return ShareFriend.fromMap(
        profile,
        friendshipId: friendshipIdsByFriend[profile['id'].toString()]!,
      );
    }).toList();
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
        .select('id, name, email, user_photo')
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
    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return {};

    final rows = await _client
        .from('ubicacion')
        .select('user_id, lat, long')
        .inFilter('user_id', ids);
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
        'sendero_id': senderoId,
      });
    } else {
      await _client
          .from('relaciones_espectadores')
          .update({'enabled': true, 'sendero_id': senderoId})
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

  void dispose() {
    _sharingTimer?.cancel();
  }
}

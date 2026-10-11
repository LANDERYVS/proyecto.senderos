import 'dart:async';

import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/modelo_sendero.dart';

// Datos del amigo necesarios para solicitar, compartir o consultar su ubicación.
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

  // Adapta el perfil de Supabase y los datos de la relación al modelo de esta función.
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

  // Crea una copia del amigo con una ubicación nueva y conserva el resto de sus datos.
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

// Agrupa las personas que observan un sendero guardado o una grabación en curso.
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

  // Crea una copia del grupo con la lista de observadores actualizada.
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

// Coordina solicitudes, relaciones de observación y publicación de ubicaciones con Supabase.
class CompartirUbicacionService {
  // Permite inyectar un cliente alternativo, por ejemplo, durante las pruebas.
  CompartirUbicacionService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  Timer? _sharingTimer;
  ShareFriend? _sharingFriend;
  int? _sharingRelationId;

  // Amigo asociado al proceso de ubicación que este servicio está compartiendo.
  ShareFriend? get sharingFriend => _sharingFriend;

  // Carga amistades, solicitudes de ubicación y perfiles para mostrarlos en la interfaz.
  Future<List<ShareFriend>> loadFriends() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return [];

    // Consulta relaciones en ambas direcciones y asocia cada amistad con su otro usuario.
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

    // Obtiene las solicitudes y las ordena de más reciente a más antigua.
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
    // Conserva el estado más reciente en cada dirección: solicitud enviada o recibida.
    for (final request in locationRequests) {
      final requesterId = request['user_id'].toString();
      final targetId = request['target_id'].toString();
      final friendId = requesterId == currentUser.id ? targetId : requesterId;
      final statuses = requestStatusesByFriend.putIfAbsent(
        friendId,
        () => <String, String>{},
      );
      final direction = requesterId == currentUser.id
          ? 'toFriend'
          : 'fromFriend';
      statuses.putIfAbsent(direction, () => request['estado'].toString());
    }

    // Completa las relaciones con los datos de perfil de cada amigo.
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

  // Envía una solicitud para que el amigo autorice recibir su ubicación.
  Future<void> requestLocation(ShareFriend friend) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) {
      throw StateError('Inicia sesión para solicitar una ubicación.');
    }

    // Evita duplicar una solicitud que todavía está pendiente.
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

    // Limpia solicitudes anteriores ya resueltas para permitir iniciar una nueva.
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
    // Registra la solicitud con estado pendiente y la fecha actual en UTC.
    await _client.from('notificaciones_espectador').insert({
      'user_id': currentUser.id,
      'target_id': friend.id,
      'estado': 'pendiente',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  // Reúne los amigos que observan senderos guardados o grabaciones activas.
  Future<List<ObservedTrailGroup>> loadObservedTrails() async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return [];

    // Obtiene las relaciones de observación habilitadas para el usuario actual.
    final relations = await _client
        .from('relaciones_espectadores')
        .select('amistad, sendero_id')
        .eq('espectador_id', currentUser.id)
        .eq('enabled', true);
    final trailIdsByFriendship = <int, int>{};
    final liveFriendshipIds = <int>{};
    // Separa las relaciones vinculadas a un sendero de las grabaciones en vivo.
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

    // Resuelve qué amigo corresponde a cada relación de amistad.
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
    // Carga perfiles, datos de los senderos asociados y ubicaciones autorizadas.
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

    // Indexa los perfiles y agrupa los observadores por sendero.
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

    // Construye grupos para los senderos guardados que tengan observadores.
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
    // Representa por separado las relaciones que corresponden a grabaciones activas.
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

  // Devuelve las ubicaciones visibles para el usuario, limitadas a quienes dieron permiso.
  Future<Map<String, LatLng>> loadLocations(Iterable<String> userIds) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return {};

    final ids = userIds.toSet().toList();
    if (ids.isEmpty) return {};

    // Solo consulta ubicaciones de usuarios con una solicitud aceptada por la cuenta actual.
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

    // Convierte las coordenadas de la base de datos en ubicaciones indexadas por ID de usuario.
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

  // Activa el envío periódico de ubicación a un amigo que ya autorizó compartirla.
  Future<void> startSharing(
    ShareFriend friend,
    Future<void> Function() publishLocation, {
    int? senderoId,
  }) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null) return;

    // Comprueba el consentimiento antes de crear o reactivar la relación de observación.
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

    // Busca una relación anterior para reactivarla en lugar de generar duplicados.
    final existing = await _client
        .from('relaciones_espectadores')
        .select('id')
        .eq('amistad', friend.friendshipId)
        .eq('espectador_id', friend.id)
        .maybeSingle();

    late final int relationId;
    if (existing == null) {
      // Registra quién observará al usuario y, si corresponde, el sendero que está siguiendo.
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
      // Habilita de nuevo la relación y la asocia al sendero actual.
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
    // Reinicia el temporizador, publica la primera ubicación y luego repite cada cinco segundos.
    _sharingTimer?.cancel();
    _sharingFriend = friend;
    _sharingRelationId = relationId;
    _sharingTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => publishLocation(),
    );
    await publishLocation();
  }

  // Guarda la posición actual para que los observadores autorizados puedan consultarla.
  Future<void> publishLocation(LatLng point) async {
    final currentUser = _client.auth.currentUser;
    if (currentUser == null || _sharingFriend == null) return;

    final location = {
      'user_id': currentUser.id,
      'lat': point.latitude,
      'long': point.longitude,
    };
    // Inserta el registro la primera vez y lo actualiza en las publicaciones siguientes.
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

  // Envía una alerta a los espectadores y devuelve cuántas personas la recibieron.
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

  // Detiene la publicación y elimina la relación y la autorización asociadas.
  Future<void> stopSharing() async {
    final currentUser = _client.auth.currentUser;
    final friend = _sharingFriend;
    final relationId = _sharingRelationId;
    if (currentUser == null || friend == null || relationId == null) return;

    // Detiene las publicaciones periódicas antes de modificar la relación remota.
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

    // Limpia el estado local antes de borrar los permisos y la relación en Supabase.
    _sharingFriend = null;
    _sharingRelationId = null;

    await _client
        .from('notificaciones_espectador')
        .delete()
        .eq('user_id', currentUser.id)
        .eq('target_id', friend.id)
        .eq('estado', 'aceptada');

    // Elimina la relación desactivada y comprueba que se haya quitado un registro.
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

    // Garantiza que no quede un temporizador activo al terminar la operación.
    _sharingTimer?.cancel();
    _sharingTimer = null;
  }

  // Cancela el temporizador si el servicio se descarta mientras comparte ubicación.
  void dispose() {
    _sharingTimer?.cancel();
  }
}

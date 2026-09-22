import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'ubicacion_amigo.dart';

class ComunidadContent extends StatefulWidget {
  const ComunidadContent({super.key});

  @override
  State<ComunidadContent> createState() => _ComunidadContentState();
}

class _ComunidadContentState extends State<ComunidadContent> {
  final _searchController = TextEditingController();
  List<_Friend> _friends = const [];
  List<_Friend> _addedFriends = const [];
  Set<String> _sentRequestIds = <String>{};
  Set<String> _requestingIds = <String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;

    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final requests = await client
          .from('solicitudes')
          .select('target_id')
          .eq('users_id', currentUser.id);
      final friendships = await client
          .from('amistades')
          .select('users_id, target_id')
          .or('users_id.eq.${currentUser.id},target_id.eq.${currentUser.id}');
      final profiles = await client
          .from('usuarios')
          .select('id, name, email, user_photo')
          .neq('id', currentUser.id)
          .order('name');

      if (!mounted) return;
      final profilesById = {
        for (final profile in profiles)
          profile['id'].toString(): _Friend.fromMap(profile),
      };
      final addedFriendIds = friendships.map<String>((friendship) {
        final usersId = friendship['users_id'].toString();
        final targetId = friendship['target_id'].toString();
        return usersId == currentUser.id ? targetId : usersId;
      }).toSet();
      final addedFriends = addedFriendIds
          .map((friendId) => profilesById[friendId])
          .whereType<_Friend>()
          .toList();
      setState(() {
        _friends = profilesById.values
            .where((friend) => !addedFriendIds.contains(friend.id))
            .toList();
        _addedFriends = addedFriends;
        _sentRequestIds = requests
            .map<String>((request) => request['target_id'].toString())
            .toSet();
        _isLoading = false;
      });
    } on PostgrestException catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendRequest(_Friend friend) async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    if (currentUser == null || _requestingIds.contains(friend.id)) return;

    setState(() => _requestingIds = {..._requestingIds, friend.id});

    try {
      final existingRequest = await client
          .from('solicitudes')
          .select('id')
          .eq('users_id', currentUser.id)
          .eq('target_id', friend.id)
          .limit(1)
          .maybeSingle();

      if (existingRequest == null) {
        await client.from('solicitudes').insert({
          'users_id': currentUser.id,
          'target_id': friend.id,
        });
      }

      final senderName =
          currentUser.userMetadata?['name']?.toString() ??
          currentUser.email ??
          'Alguien';
      final notificationMessage =
          '$senderName te ha enviado una solicitud de amistad.';
      final existingNotification = await client
          .from('notificaciones')
          .select('id')
          .eq('user_id', friend.id)
          .eq('type', 'friend_request')
          .eq('status', false)
          .eq('message', notificationMessage)
          .limit(1)
          .maybeSingle();

      if (existingNotification == null) {
        await client.from('notificaciones').insert({
          'user_id': friend.id,
          'type': 'friend_request',
          'message': notificationMessage,
          'status': false,
        });
      }

      if (!mounted) return;
      setState(() {
        _sentRequestIds = {..._sentRequestIds, friend.id};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud enviada a ${friend.name}')),
      );
    } on PostgrestException catch (_) {
      return;
    } catch (_) {
      return;
    } finally {
      if (mounted) {
        setState(() {
          final pending = {..._requestingIds}..remove(friend.id);
          _requestingIds = pending;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          'Encuentra tu grupo',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Conecta con personas que también disfrutan salir a explorar.',
          style: TextStyle(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: 'Buscar por nombre o usuario',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: IconButton(
              onPressed: () {},
              tooltip: 'Filtros',
              icon: const Icon(Icons.tune_outlined),
            ),
            filled: true,
            fillColor: colors.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Agregar personas',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            TextButton(onPressed: () {}, child: const Text('Ver todas')),
          ],
        ),
        const SizedBox(height: 4),
        if (_isLoading)
          const Center(child: CircularProgressIndicator())
        else if (_filteredFriends.isEmpty)
          const Text('No encontramos personas con esa búsqueda.')
        else
          for (final friend in _filteredFriends)
            _FriendTile(
              friend: friend,
              requestSent: _sentRequestIds.contains(friend.id),
              isSending: _requestingIds.contains(friend.id),
              onSendRequest: () => _sendRequest(friend),
            ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(),
        ),
        Text(
          'Agregados',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        if (_addedFriends.isEmpty)
          const Text('Aquí aparecerán las personas que acepten tu solicitud.')
        else
          for (final friend in _addedFriends)
            _AddedFriendTile(
              friend: friend,
              onViewLocation: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => UbicacionAmigoPage(
                    friendId: friend.id,
                    friendName: friend.name,
                  ),
                ),
              ),
            ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: colors.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Icon(Icons.groups_outlined, size: 30, color: colors.primary),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'Comparte tus senderos con tu comunidad y descubre nuevas rutas.',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<_Friend> get _filteredFriends {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _friends;
    return _friends.where((friend) {
      return friend.name.toLowerCase().contains(query) ||
          friend.username.toLowerCase().contains(query);
    }).toList();
  }
}

class _Friend {
  const _Friend({
    required this.id,
    required this.name,
    required this.username,
    required this.initials,
    this.photoUrl,
  });

  factory _Friend.fromMap(Map<String, dynamic> profile) {
    final name = profile['name']?.toString().trim();
    final email = profile['email']?.toString().trim();
    final displayName = name?.isNotEmpty == true ? name! : email ?? 'Usuario';
    final initials = displayName
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return _Friend(
      id: profile['id'].toString(),
      name: displayName,
      username: email ?? '',
      initials: initials.isEmpty ? '?' : initials,
      photoUrl: profile['user_photo']?.toString(),
    );
  }

  final String id;
  final String name;
  final String username;
  final String initials;
  final String? photoUrl;
}

class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.requestSent,
    required this.isSending,
    required this.onSendRequest,
  });

  final _Friend friend;
  final bool requestSent;
  final bool isSending;
  final VoidCallback onSendRequest;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          leading: CircleAvatar(
            backgroundColor: colors.primaryContainer,
            foregroundColor: colors.onPrimaryContainer,
            backgroundImage: friend.photoUrl?.isNotEmpty == true
                ? NetworkImage(friend.photoUrl!)
                : null,
            child: Text(
              friend.initials,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          title: Text(
            friend.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: friend.username.isEmpty ? null : Text(friend.username),
          trailing: OutlinedButton.icon(
            onPressed: requestSent || isSending ? null : onSendRequest,
            icon: isSending
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    requestSent ? Icons.check : Icons.person_add_alt_1,
                    size: 18,
                  ),
            label: Text(requestSent ? 'Enviada' : 'Agregar'),
          ),
        ),
      ),
    );
  }
}

class _AddedFriendTile extends StatelessWidget {
  const _AddedFriendTile({required this.friend, required this.onViewLocation});

  final _Friend friend;
  final VoidCallback onViewLocation;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          backgroundImage: friend.photoUrl?.isNotEmpty == true
              ? NetworkImage(friend.photoUrl!)
              : null,
          child: Text(friend.initials),
        ),
        title: Text(friend.name),
        subtitle: Text(
          friend.username.isEmpty
              ? 'target_id: ${friend.id}'
              : '${friend.username}\ntarget_id: ${friend.id}',
        ),
        trailing: IconButton(
          onPressed: onViewLocation,
          tooltip: 'Ver ubicación',
          icon: const Icon(Icons.location_on_outlined),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/modelo_sendero.dart';
import 'perfil_publico.dart';
import '../widgets/avatar_usuario.dart';

// Contenido de la pantalla de amistades; recibe el texto de búsqueda desde su pantalla contenedora.
class AmigosContent extends StatefulWidget {
  const AmigosContent({super.key, this.searchTerm = '', this.onSearchChanged});

  final String searchTerm;
  final ValueChanged<String>? onSearchChanged;

  @override
  State<AmigosContent> createState() => _AmigosContentState();
}

class _AmigosContentState extends State<AmigosContent> {
  // Personas sugeridas, amistades actuales y solicitudes en curso o ya enviadas.
  List<_Friend> _friends = const [];
  List<_Friend> _addedFriends = const [];
  Set<String> _sentRequestIds = <String>{};
  Set<String> _requestingIds = <String>{};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Obtiene perfiles, amistades existentes y solicitudes enviadas al iniciar la pantalla.
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    // Activa el indicador tanto en la carga inicial como al actualizar con "deslizar para refrescar".
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;

    // Sin una sesión no hay un usuario con el que consultar amistades.
    if (currentUser == null) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      debugPrint(
        'No se cargaron personas: no hay sesión iniciada en Supabase.',
      );
      return;
    }

    var loadingStep = 'notificaciones_solicitudes';
    try {
      // Recupera a quién ya se le envió una solicitud desde esta cuenta.
      final sentRequests = await client
          .from('notificaciones_solicitudes')
          .select('target_id')
          .eq('users_id', currentUser.id);

      loadingStep = 'amistades';
      // Busca las relaciones donde la cuenta actual aparece como origen o destino.
      final friendships = await client
          .from('amistades')
          .select('users_id, target_id')
          .or('users_id.eq.${currentUser.id},target_id.eq.${currentUser.id}');

      loadingStep = 'usuarios';
      // Carga los perfiles disponibles, excluyendo al usuario que inició sesión.
      final profiles = await client
          .from('usuarios')
          .select('id, name, email, user_photo, premium')
          .neq('id', currentUser.id)
          .order('name');

      if (!mounted) return;
      // Convierte los perfiles en un índice por ID para resolver las relaciones fácilmente.
      final profilesById = {
        for (final profile in profiles)
          profile['id'].toString(): _Friend.fromMap(profile),
      };

      // Normaliza cada amistad para obtener el ID de la otra persona, sin importar la dirección.
      final addedFriendIds = friendships.map<String>((friendship) {
        final usersId = friendship['users_id'].toString();
        final targetId = friendship['target_id'].toString();
        return usersId == currentUser.id ? targetId : usersId;
      }).toSet();

      // Guarda los IDs a los que ya se les envió una solicitud.
      final sentRequestIds = sentRequests
          .map<String>((request) => request['target_id'].toString())
          .toSet();

      // Separa los perfiles entre sugerencias y amistades confirmadas.
      final visibleFriends = profilesById.values
          .where((friend) => !addedFriendIds.contains(friend.id))
          .toList();

      final addedFriends = addedFriendIds
          .map((friendId) => profilesById[friendId])
          .whereType<_Friend>()
          .toList();

      // Publica los datos cargados y termina el estado de carga.
      setState(() {
        _friends = visibleFriends;
        _addedFriends = addedFriends;
        _sentRequestIds = sentRequestIds;
        _requestingIds = <String>{};
        _isLoading = false;
      });
    } on PostgrestException catch (error) {
      // Identifica la consulta fallida para facilitar el diagnóstico de errores de Supabase.
      debugPrint(
        'No se pudieron cargar personas desde $loadingStep '
        '(${error.code ?? 'Supabase'}): ${error.message}; '
        'detalle: ${error.details}; sugerencia: ${error.hint}',
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
    } catch (error) {
      debugPrint('No se pudieron cargar personas desde $loadingStep: $error');
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

    // Evita envíos duplicados y muestra el progreso solo en la fila seleccionada.
    setState(() => _requestingIds = {..._requestingIds, friend.id});

    try {
      // Comprueba si ya existe una solicitud entre estas dos personas antes de insertar otra.
      final existingRequest = await client
          .from('notificaciones_solicitudes')
          .select('id')
          .eq('users_id', currentUser.id)
          .eq('target_id', friend.id)
          .limit(1)
          .maybeSingle();

      if (existingRequest == null) {
        // Registra la solicitud como pendiente para que el destinatario pueda responderla.
        await client.from('notificaciones_solicitudes').insert({
          'users_id': currentUser.id,
          'target_id': friend.id,
          'estado': 'pendiente',
        });
      }

      if (!mounted) return;
      // Marca la solicitud como enviada y confirma la acción al usuario.
      setState(() {
        _sentRequestIds = {..._sentRequestIds, friend.id};
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Solicitud enviada a ${friend.name}')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo enviar la solicitud (${error.code ?? 'Supabase'}): '
            '${error.message}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo enviar la solicitud: $error')),
      );
    } finally {
      // Quita el indicador de progreso incluso si la consulta falla.
      if (mounted) {
        setState(() {
          final pending = {..._requestingIds}..remove(friend.id);
          _requestingIds = pending;
        });
      }
    }
  }

  Future<void> _removeFriend(_Friend friend) async {
    final client = Supabase.instance.client;
    final currentUser = client.auth.currentUser;
    if (currentUser == null) return;

    // Pide confirmación antes de eliminar la relación de amistad.
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar amigo'),
        content: Text('¿Quieres quitar a ${friend.name} de tus amigos?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldRemove != true) return;

    try {
      // Borra la relación en ambas direcciones, ya que puede estar guardada con cualquiera de ellas.
      await client
          .from('amistades')
          .delete()
          .eq('users_id', currentUser.id)
          .eq('target_id', friend.id);
      await client
          .from('amistades')
          .delete()
          .eq('users_id', friend.id)
          .eq('target_id', currentUser.id);

      if (!mounted) return;
      // Mueve a la persona de la lista de amistades a la lista de sugerencias.
      setState(() {
        _addedFriends = [..._addedFriends]
          ..removeWhere((item) => item.id == friend.id);
        _friends = [
          ..._friends,
          friend,
        ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${friend.name} ya no está en tus amigos.')),
      );
    } on PostgrestException catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar al amigo.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo eliminar al amigo.')),
      );
    }
  }

  // Abre el perfil público con los datos ya disponibles para mostrarlo de inmediato.
  void _openFriendProfile(_Friend friend) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => PublicProfilePage(
          userId: friend.id,
          initialName: friend.name,
          initialEmail: friend.username,
          initialPhotoUrl: friend.photoUrl,
          isPremium: friend.isPremium,
        ),
      ),
    );
  }

  // Construye el encabezado de cada sección de la lista.
  Widget _buildSectionHeader(String title) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        TextButton(onPressed: () {}, child: const Text('Ver todas')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      // Permite volver a consultar perfiles y relaciones al arrastrar la lista hacia abajo.
      onRefresh: _loadUsers,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: 8),
          _buildSectionHeader('Agregar personas'),
          const SizedBox(height: 4),
          // Muestra el progreso, el estado vacío o las personas que se pueden agregar.
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
                onTap: () => _openFriendProfile(friend),
              ),
          // Separa las sugerencias de las amistades que ya fueron agregadas.
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          _buildSectionHeader('Agregados'),
          const SizedBox(height: 8),
          if (_addedFriends.isEmpty)
            const Text('Aquí aparecerán las personas que acepten tu solicitud.')
          else
            for (final friend in _addedFriends)
              _AddedFriendTile(
                friend: friend,
                onRemoveFriend: () => _removeFriend(friend),
                onTap: () => _openFriendProfile(friend),
              ),
        ],
      ),
    );
  }

  // Filtra las sugerencias por nombre o correo usando el texto recibido del buscador.
  List<_Friend> get _filteredFriends {
    final query = widget.searchTerm.trim().toLowerCase();
    if (query.isEmpty) return _friends;
    return _friends.where((friend) {
      return friend.name.toLowerCase().contains(query) ||
          friend.username.toLowerCase().contains(query);
    }).toList();
  }
}

// Datos de perfil necesarios para mostrar y gestionar una amistad en esta pantalla.
class _Friend {
  const _Friend({
    required this.id,
    required this.name,
    required this.username,
    required this.initials,
    required this.isPremium,
    this.photoUrl,
  });

  // Adapta el perfil de Supabase al modelo que utiliza la interfaz de amistades.
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
      photoUrl: ExploreTrail.publicR2Url(profile['user_photo']?.toString()),
      isPremium: profile['premium'] == true,
    );
  }

  // Identidad, datos visibles y estado premium del perfil.
  final String id;
  final String name;
  final String username;
  final String initials;
  final String? photoUrl;
  final bool isPremium;
}

// Fila de una persona sugerida, con acceso al perfil y acción para enviar solicitud.
class _FriendTile extends StatelessWidget {
  const _FriendTile({
    required this.friend,
    required this.requestSent,
    required this.isSending,
    required this.onSendRequest,
    required this.onTap,
  });

  final _Friend friend;
  final bool requestSent;
  final bool isSending;
  final VoidCallback onSendRequest;
  final VoidCallback onTap;

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
          leading: DefaultUserAvatar(
            radius: 20,
            backgroundColor: colors.primaryContainer,
            imageUrl: friend.photoUrl,
          ),
          title: Text(
            friend.name,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: friend.username.isEmpty ? null : Text(friend.username),
          // Al tocar los datos de la persona se abre su perfil público.
          onTap: onTap,
          // Desactiva el botón mientras la solicitud se envía o si ya fue enviada.
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

// Fila de una amistad existente, con acceso al perfil y opción para quitarla.
class _AddedFriendTile extends StatelessWidget {
  const _AddedFriendTile({
    required this.friend,
    required this.onRemoveFriend,
    required this.onTap,
  });

  final _Friend friend;
  final VoidCallback onRemoveFriend;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      child: ListTile(
        leading: DefaultUserAvatar(radius: 20, imageUrl: friend.photoUrl),
        title: Text(friend.name),
        subtitle: friend.username.isEmpty ? null : Text(friend.username),
        // Abre el perfil público de esta amistad.
        onTap: onTap,
        // Solicita confirmar antes de eliminar esta relación.
        trailing: IconButton(
          onPressed: onRemoveFriend,
          tooltip: 'Eliminar amigo',
          icon: const Icon(Icons.person_remove_alt_1_outlined),
        ),
      ),
    );
  }
}

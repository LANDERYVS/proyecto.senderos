import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SenderoReaccionesException implements Exception {
  const SenderoReaccionesException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SenderoReaccionState {
  const SenderoReaccionState({
    required this.likes,
    required this.dislikes,
    required this.userReaction,
  });

  final int likes;
  final int dislikes;
  final String? userReaction;
}

class SenderoReaccionesService {
  SenderoReaccionesService({
    SupabaseClient? client,
    Future<SharedPreferences> Function()? preferencesLoader,
  }) : _client = client ?? Supabase.instance.client,
       _preferencesLoader = preferencesLoader ?? SharedPreferences.getInstance;

  final SupabaseClient _client;
  final Future<SharedPreferences> Function() _preferencesLoader;

  Future<SenderoReaccionState> loadState(int senderoId) async {
    try {
      final sendero = await _client
          .from('senderos')
          .select('likes, dislikes')
          .eq('id', senderoId)
          .single();
      final user = _client.auth.currentUser;
      final preferences = await _preferencesLoader();
      final userReaction = user == null
          ? null
          : preferences.getString(_reactionKey(user.id, senderoId));

      return SenderoReaccionState(
        likes: (sendero['likes'] as num?)?.toInt() ?? 0,
        dislikes: (sendero['dislikes'] as num?)?.toInt() ?? 0,
        userReaction: userReaction,
      );
    } on PostgrestException catch (error) {
      throw SenderoReaccionesException(
        'No se pudieron cargar las reacciones: ${error.message}',
      );
    }
  }

  Future<SenderoReaccionState> castVote(int senderoId, String reaction) async {
    if (reaction != 'like' && reaction != 'dislike') {
      throw const SenderoReaccionesException('La reacción no es válida.');
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const SenderoReaccionesException(
        'Inicia sesión para reaccionar a un sendero.',
      );
    }

    final preferences = await _preferencesLoader();
    final key = _reactionKey(user.id, senderoId);
    if (preferences.getString(key) != null) {
      throw const SenderoReaccionesException(
        'Ya votaste este sendero desde este dispositivo.',
      );
    }

    try {
      final result = await _client.rpc(
        'increment_sendero_reaction',
        params: {'p_sendero_id': senderoId, 'p_reaction': reaction},
      );
      if (result is! Map) {
        throw const SenderoReaccionesException(
          'La respuesta de la reacción no tiene un formato válido.',
        );
      }

      final savedLocally = await preferences.setString(key, reaction);
      if (!savedLocally) {
        throw const SenderoReaccionesException(
          'El voto se registró, pero no se pudo guardar el bloqueo local. '
          'Para evitar duplicarlo, no vuelvas a tocar el botón en este dispositivo.',
        );
      }

      return SenderoReaccionState(
        likes: (result['likes'] as num?)?.toInt() ?? 0,
        dislikes: (result['dislikes'] as num?)?.toInt() ?? 0,
        userReaction: reaction,
      );
    } on PostgrestException catch (error) {
      throw SenderoReaccionesException(
        'No se pudo guardar el voto: ${error.message}',
      );
    }
  }

  Future<SenderoReaccionState> removeVote(
    int senderoId,
    String reaction,
  ) async {
    if (reaction != 'like' && reaction != 'dislike') {
      throw const SenderoReaccionesException('La reacción no es válida.');
    }
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const SenderoReaccionesException(
        'Inicia sesión para quitar tu voto.',
      );
    }

    final preferences = await _preferencesLoader();
    final key = _reactionKey(user.id, senderoId);
    if (preferences.getString(key) != reaction) {
      throw const SenderoReaccionesException(
        'No se encontró tu voto en este dispositivo.',
      );
    }

    try {
      final result = await _client.rpc(
        'decrement_sendero_reaction',
        params: {'p_sendero_id': senderoId, 'p_reaction': reaction},
      );
      if (result is! Map) {
        throw const SenderoReaccionesException(
          'La respuesta de la reacción no tiene un formato válido.',
        );
      }

      final removedLocally = await preferences.remove(key);
      if (!removedLocally) {
        throw const SenderoReaccionesException(
          'El voto se quitó del contador, pero no se pudo actualizar el '
          'bloqueo local. Cierra y vuelve a abrir el sendero antes de votar.',
        );
      }

      return SenderoReaccionState(
        likes: (result['likes'] as num?)?.toInt() ?? 0,
        dislikes: (result['dislikes'] as num?)?.toInt() ?? 0,
        userReaction: null,
      );
    } on PostgrestException catch (error) {
      throw SenderoReaccionesException(
        'No se pudo quitar el voto: ${error.message}',
      );
    }
  }

  String _reactionKey(String userId, int senderoId) =>
      'sendero_reaction_${userId}_$senderoId';
}

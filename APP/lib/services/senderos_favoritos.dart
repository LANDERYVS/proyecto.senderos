// Aquí se implementa un servicio de la aplicación.


import 'package:supabase_flutter/supabase_flutter.dart';
// La clase SenderosFavoritosException reúne los datos y las acciones de esta parte de la app.

class SenderosFavoritosException implements Exception {
  const SenderosFavoritosException(this.message);

  final String message;

  @override
  String toString() => message;
}
// La clase SenderosFavoritosService reúne los datos y las acciones de esta parte de la app.

class SenderosFavoritosService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<Set<int>> loadFavoriteIds() async {
    final user = _client.auth.currentUser;
    if (user == null) return {};

    try {
      final rows = await _client
          .from('senderos_favoritos')
          .select('sendero_id')
          .eq('user_id', user.id);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map((row) => (row['sendero_id'] as num).toInt())
          .toSet();
    } on PostgrestException catch (error) {
      throw SenderosFavoritosException(
        'No se pudieron cargar los favoritos: ${error.message}',
      );
    }
  }
// Agrega el nuevo elemento a la lista que muestra la pantalla.

  Future<void> addFavorite(int senderoId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const SenderosFavoritosException(
        'Inicia sesión para guardar senderos en tus favoritos.',
      );
    }

    try {
      await _client.from('senderos_favoritos').upsert({
        'user_id': user.id,
        'sendero_id': senderoId,
      }, onConflict: 'user_id,sendero_id');
    } on PostgrestException catch (error) {
      throw SenderosFavoritosException(
        'No se pudo guardar el favorito: ${error.message}',
      );
    }
  }
// Quita el elemento seleccionado de la lista o de los datos guardados.

  Future<void> removeFavorite(int senderoId) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const SenderosFavoritosException(
        'Inicia sesión para modificar tus favoritos.',
      );
    }

    try {
      await _client
          .from('senderos_favoritos')
          .delete()
          .eq('user_id', user.id)
          .eq('sendero_id', senderoId);
    } on PostgrestException catch (error) {
      throw SenderosFavoritosException(
        'No se pudo quitar el favorito: ${error.message}',
      );
    }
  }
}

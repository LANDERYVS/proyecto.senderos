import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/explore_trail.dart';

class ObtenerSenderoException implements Exception {
  const ObtenerSenderoException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => message;
}

class ObtenerSenderoService {
  final _supabase = Supabase.instance.client;

  Future<List<ExploreTrail>> obtenerSenderos() async {
    try {
      final rows = await _supabase
          .from('senderos')
          .select(
            'sendero_nick, descripcion, dificultad, distancia, '
            'foto_sendero, user_id',
          )
          .order('fecha_creacion', ascending: false);

      final rawTrails = (rows as List)
          .whereType<Map<String, dynamic>>()
          .toList();
      final userIds = rawTrails
          .map((row) => row['user_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();
      final userNames = <String, String>{};

      if (userIds.isNotEmpty) {
        try {
          final profiles = await _supabase
              .from('usuarios')
              .select('id, name')
              .inFilter('id', userIds);
          for (final profile in profiles as List) {
            final profileMap = profile as Map<String, dynamic>;
            final id = profileMap['id']?.toString();
            final name = profileMap['name']?.toString().trim();
            if (id != null && name != null && name.isNotEmpty) {
              userNames[id] = name;
            }
          }
        } on Exception {
          // El UUID identifica al autor si usuarios no permite lectura.
        }
      }

      return rawTrails
          .map((row) => ExploreTrail.fromMap(row, userNames: userNames))
          .toList();
    } on PostgrestException catch (error) {
      throw ObtenerSenderoException(_postgrestError(error), cause: error);
    } on SocketException {
      throw const ObtenerSenderoException(
        'No hay conexión a Internet. Comprueba tu conexión y reintenta.',
      );
    } on Exception catch (error) {
      throw ObtenerSenderoException(
        'No se pudieron cargar los senderos. Intenta nuevamente.',
        cause: error,
      );
    }
  }

  String _postgrestError(PostgrestException error) {
    switch (error.code) {
      case '42501':
        return 'No tienes permisos para consultar los senderos. Activa la '
            'política SELECT de la tabla senderos.';
      case '42P01':
      case 'PGRST205':
        return 'La tabla senderos no existe en Supabase. Revisa la base de datos.';
      case '42703':
      case 'PGRST204':
        return 'Falta una columna de senderos en Supabase. Revisa el esquema.';
      case 'PGRST301':
        return 'La sesión no es válida. Inicia sesión nuevamente.';
      default:
        return 'Supabase no permite listar los senderos. Revisa RLS y reintenta.';
    }
  }
}

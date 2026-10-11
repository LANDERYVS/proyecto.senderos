import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/waypoints_sendero.dart';

// Consulta en Supabase los puntos de interés asociados a un sendero.
class WaypointService {
  // Devuelve los marcadores del sendero como objetos TrailWaypoint.
  Future<List<TrailWaypoint>> fetchForTrail(int senderoId) async {
    // Selecciona solo el tipo de marcador y sus coordenadas.
    final rows = await Supabase.instance.client
        .from('waypoint')
        .select('type, lat, long')
        .eq('sendero_id', senderoId);

    // Convierte cada fila válida de la tabla en el modelo usado por la aplicación.
    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(TrailWaypoint.fromMap)
        .toList();
  }
}

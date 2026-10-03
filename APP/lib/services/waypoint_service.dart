import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/trail_waypoint.dart';

class WaypointService {
  Future<List<TrailWaypoint>> fetchForTrail(int senderoId) async {
    final rows = await Supabase.instance.client
        .from('waypoint')
        .select('type, lat, long')
        .eq('sendero_id', senderoId);

    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map(TrailWaypoint.fromMap)
        .toList();
  }
}

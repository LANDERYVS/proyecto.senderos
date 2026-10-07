import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PremiumAccessService {
  String _preferenceKey(String userId) => 'premium_demo_override_$userId';

  Future<bool?> loadLocalOverride(String userId) async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_preferenceKey(userId));
  }

  Future<bool> hasAccess() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    final localOverride = await loadLocalOverride(user.id);
    if (localOverride != null) return localOverride;

    final profile = await Supabase.instance.client
        .from('usuarios')
        .select('premium')
        .eq('id', user.id)
        .maybeSingle();
    return profile?['premium'] == true;
  }

  Future<bool> saveLocalOverride(String userId, bool? value) async {
    final preferences = await SharedPreferences.getInstance();
    return value == null
        ? preferences.remove(_preferenceKey(userId))
        : preferences.setBool(_preferenceKey(userId), value);
  }
}

import 'package:shared_preferences/shared_preferences.dart';

// Last known role per user, so AuthGate can route a signed-in user while
// offline instead of bouncing them to the login screen.

String _key(String uid) => 'cached_role_$uid';

Future<void> cacheRole(String uid, String role) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), role);
  } catch (_) {}
}

Future<String?> cachedRole(String uid) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key(uid));
  } catch (_) {
    return null;
  }
}

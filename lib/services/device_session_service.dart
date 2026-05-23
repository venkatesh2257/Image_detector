import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Stable device id until user login (then link [userId] on captures).
class DeviceSessionService {
  static const _prefsKey = 'milk_mirror_device_id';

  String? _cached;

  Future<String> deviceId() async {
    if (_cached != null && _cached!.isNotEmpty) return _cached!;
    final prefs = await SharedPreferences.getInstance();
    var id = prefs.getString(_prefsKey);
    if (id == null || id.isEmpty) {
      id =
          'dev_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(999999)}';
      await prefs.setString(_prefsKey, id);
    }
    _cached = id;
    return id;
  }

  /// Call after Firebase Auth login to attach future captures to this user.
  Future<void> setLinkedUserId(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null || userId.isEmpty) {
      await prefs.remove('milk_mirror_user_id');
    } else {
      await prefs.setString('milk_mirror_user_id', userId);
    }
  }

  Future<String?> linkedUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('milk_mirror_user_id');
  }
}

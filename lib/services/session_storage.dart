import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/client_models.dart';

/// Remembers who is signed in so clients and staff are not asked to log in
/// again after closing the app.
class SessionStorage {
  SessionStorage({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _kClientId = 'client_id';
  static const _kStaffEmail = 'staff_email';
  static const _kStaffProfile = 'staff_profile';
  static const _kAccessToken = 'access_token';

  Future<void> saveClientId(String id) =>
      _secure.write(key: _kClientId, value: id);

  Future<String?> getClientId() => _secure.read(key: _kClientId);

  Future<void> clearClientId() => _secure.delete(key: _kClientId);

  Future<void> saveStaffEmail(String email) =>
      _secure.write(key: _kStaffEmail, value: email);

  Future<String?> getStaffEmail() => _secure.read(key: _kStaffEmail);

  Future<void> clearStaffEmail() => _secure.delete(key: _kStaffEmail);

  Future<void> saveStaffProfile(StaffProfile staff) => _secure.write(
        key: _kStaffProfile,
        value: jsonEncode(staff.toMap()),
      );

  Future<StaffProfile?> getStaffProfile() async {
    final raw = await _secure.read(key: _kStaffProfile);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final id = (map['id'] ?? '') as String;
      if (id.isEmpty) return null;
      return StaffProfile.fromMap(id, map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clearStaffProfile() => _secure.delete(key: _kStaffProfile);

  Future<void> saveAccessToken(String token) =>
      _secure.write(key: _kAccessToken, value: token);

  Future<String?> getAccessToken() => _secure.read(key: _kAccessToken);

  Future<void> clearAccessToken() => _secure.delete(key: _kAccessToken);

  Future<void> clearStaffSession() async {
    await clearStaffEmail();
    await clearStaffProfile();
    await clearAccessToken();
  }

  static const _kStaffLastRead = 'staff_last_read';

  Future<Map<String, String>> _staffLastReadMap() async {
    final raw = await _secure.read(key: _kStaffLastRead);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map((key, value) => MapEntry('$key', '$value'));
    } catch (_) {
      return {};
    }
  }

  Future<DateTime?> getStaffLastRead(String threadId) async {
    final raw = (await _staffLastReadMap())[threadId];
    return raw == null ? null : DateTime.tryParse(raw);
  }

  Future<void> setStaffLastRead(String threadId, DateTime at) async {
    final map = await _staffLastReadMap();
    map[threadId] = at.toIso8601String();
    await _secure.write(key: _kStaffLastRead, value: jsonEncode(map));
  }
}

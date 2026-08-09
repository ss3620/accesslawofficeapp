import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Remembers who is signed in so clients are not asked for their activation
/// code again after closing the app.
class SessionStorage {
  SessionStorage({FlutterSecureStorage? secure})
      : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _kClientId = 'client_id';
  static const _kStaffEmail = 'staff_email';
  static const _kAccessToken = 'access_token';

  Future<void> saveClientId(String id) =>
      _secure.write(key: _kClientId, value: id);

  Future<String?> getClientId() => _secure.read(key: _kClientId);

  Future<void> clearClientId() => _secure.delete(key: _kClientId);

  Future<void> saveStaffEmail(String email) =>
      _secure.write(key: _kStaffEmail, value: email);

  Future<String?> getStaffEmail() => _secure.read(key: _kStaffEmail);

  Future<void> clearStaffEmail() => _secure.delete(key: _kStaffEmail);

  Future<void> saveAccessToken(String token) =>
      _secure.write(key: _kAccessToken, value: token);

  Future<String?> getAccessToken() => _secure.read(key: _kAccessToken);

  Future<void> clearAccessToken() => _secure.delete(key: _kAccessToken);
}

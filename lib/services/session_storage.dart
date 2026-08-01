import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class SessionStorage {
  SessionStorage({
    FlutterSecureStorage? secure,
  }) : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  static const _kAccess = 'staff_access_token';
  static const _kRefresh = 'staff_refresh_token';
  static const _kVisitId = 'client_visit_id';
  static const _kVisitToken = 'client_visit_token';

  Future<void> saveStaffSession(AuthSession session) async {
    await _secure.write(key: _kAccess, value: session.accessToken);
    await _secure.write(key: _kRefresh, value: session.refreshToken);
  }

  Future<String?> getStaffAccessToken() => _secure.read(key: _kAccess);

  Future<void> clearStaffSession() async {
    await _secure.delete(key: _kAccess);
    await _secure.delete(key: _kRefresh);
  }

  Future<void> saveClientSession(ClientSession session) async {
    await _secure.write(key: _kVisitId, value: session.visitId);
    await _secure.write(key: _kVisitToken, value: session.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kVisitId, session.visitId);
  }

  Future<ClientSession?> getClientSession() async {
    final id = await _secure.read(key: _kVisitId);
    final token = await _secure.read(key: _kVisitToken);
    if (id == null || token == null) return null;
    return ClientSession(visitId: id, token: token);
  }

  Future<void> clearClientSession() async {
    await _secure.delete(key: _kVisitId);
    await _secure.delete(key: _kVisitToken);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kVisitId);
  }
}
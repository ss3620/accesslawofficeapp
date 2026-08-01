import 'dart:async';
import 'dart:math';

import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../rbac/roles.dart';

/// Mock WordPress-backed API for local MVP demos.
/// Swap [MockApi] for a real HTTP client later (`/wp-json/alf/v1/`).
class MockApi {
  MockApi() {
    _seed();
  }

  final _uuid = const Uuid();
  final _rng = Random();

  late LobbyConfig _config;
  final List<Visit> _visits = [];
  final List<StaffUser> _staff = [];
  final Map<String, String> _passwords = {};
  final Map<String, String> _otps = {};

  void _seed() {
    _config = LobbyConfig(
      isOpen: true,
      waitingCount: 0,
      hoursCopy:
          'Mon–Fri: 9:00 AM – 5:00 PM CST\nSat–Sun: 10:00 AM – 3:30 PM CST',
      verifyMode: VerifyMode.none,
      matters: const [
        'Family-based immigration',
        'Employment-based immigration',
        'Asylum / humanitarian',
        'Naturalization / citizenship',
        'Deportation defense',
        'Visa renewal / extension',
        'Other immigration matter',
      ],
      receptionZoomUrl: 'https://zoom.us/j/1111111111',
      attorneyZoomUrl: 'https://zoom.us/j/2222222222',
      receptionMeetingNumber: '1111111111',
      attorneyMeetingNumber: '2222222222',
      receptionPasscode: 'access',
      attorneyPasscode: 'attorney',
      featureMessaging: false,
      featureVoip: false,
      featureMeetingSdk: false,
    );

    _staff.addAll([
      const StaffUser(
        id: 'admin-1',
        username: 'admin',
        email: 'admin@accesslawoffice.com',
        displayName: 'Office Admin',
        role: AppRole.admin,
        capabilities: ['manage_options', 'alf_manage_lobby'],
      ),
      const StaffUser(
        id: 'recv-1',
        username: 'receptionist',
        email: 'front@accesslawoffice.com',
        displayName: 'Front Desk',
        role: AppRole.receptionist,
        capabilities: ['alf_manage_lobby'],
      ),
    ]);
    _passwords['admin'] = 'admin123';
    _passwords['receptionist'] = 'reception123';
  }

  Future<T> _delay<T>(T value, [int ms = 350]) async {
    await Future<void>.delayed(Duration(milliseconds: ms));
    return value;
  }

  // —— Public / client ——

  Future<LobbyConfig> getConfig() async {
    return _delay(
      _config.copyWith(
        waitingCount: _visits
            .where((v) =>
                v.status == VisitStatus.waiting ||
                v.status == VisitStatus.ready)
            .length,
      ),
    );
  }

  Future<void> sendOtp(String phone) async {
    _otps[phone] = '123456';
    await _delay(null);
  }

  Future<bool> verifyOtp(String phone, String code) async {
    await _delay(null);
    return _otps[phone] == code || code == '123456';
  }

  Future<bool> verifyCaptcha(String token) async {
    await _delay(null);
    return token.trim().isNotEmpty;
  }

  Future<Visit> checkIn({
    required String fullName,
    required String phone,
    required String matter,
  }) async {
    if (!_config.isOpen) {
      throw StateError('The Virtual Lobby is currently closed.');
    }
    final waiting = _visits.where((v) => v.status == VisitStatus.waiting).length;
    final visit = Visit(
      id: _uuid.v4(),
      token: _uuid.v4(),
      fullName: fullName.trim(),
      phone: phone.trim(),
      matter: matter,
      status: VisitStatus.waiting,
      position: waiting + 1,
      createdAt: DateTime.now(),
    );
    _visits.insert(0, visit);
    return _delay(visit, 500);
  }

  Future<Visit> getVisit(String visitId, String token) async {
    final visit = _visits.firstWhere(
      (v) => v.id == visitId && v.token == token,
      orElse: () => throw StateError('Visit not found'),
    );
    return _delay(_withLivePosition(visit));
  }

  Visit _withLivePosition(Visit visit) {
    if (visit.status != VisitStatus.waiting) return visit;
    final ahead = _visits
        .where((v) =>
            v.status == VisitStatus.waiting &&
            v.createdAt.isBefore(visit.createdAt))
        .length;
    return visit.copyWith(position: ahead + 1);
  }

  Future<Visit> markJoined(String visitId, String token) async {
    final i = _visits.indexWhere((v) => v.id == visitId && v.token == token);
    if (i < 0) throw StateError('Visit not found');
    final current = _visits[i];
    final next = current.status == VisitStatus.ready
        ? VisitStatus.inMeeting
        : current.status == VisitStatus.withAttorney
            ? VisitStatus.withAttorney
            : current.status;
    _visits[i] = current.copyWith(status: next, joinedAt: DateTime.now());
    return _delay(_visits[i]);
  }

  // —— Staff auth ——

  Future<AuthSession> login(String username, String password) async {
    await _delay(null, 450);
    final user = _staff.cast<StaffUser?>().firstWhere(
          (u) =>
              u != null &&
              u.active &&
              (u.username == username || u.email == username),
          orElse: () => null,
        );
    if (user == null || _passwords[user.username] != password) {
      throw StateError('Invalid username or password');
    }
    if (!user.capabilities.contains('alf_manage_lobby') &&
        !user.capabilities.contains('manage_options')) {
      throw StateError('This account cannot access the staff app');
    }
    return AuthSession(
      accessToken: 'access-${user.id}-${_rng.nextInt(99999)}',
      refreshToken: 'refresh-${user.id}',
      user: user,
    );
  }

  Future<StaffUser> me(String accessToken) async {
    final id = accessToken.split('-').skip(1).first;
    final user = _staff.firstWhere((u) => u.id == id);
    return _delay(user);
  }

  // —— Queue ——

  Future<List<Visit>> getQueue() async {
    final active = _visits
        .where((v) =>
            v.status != VisitStatus.completed &&
            v.status != VisitStatus.dismissed)
        .map(_withLivePosition)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return _delay(active);
  }

  Future<Visit> queueAction(String visitId, QueueAction action) async {
    final i = _visits.indexWhere((v) => v.id == visitId);
    if (i < 0) throw StateError('Visit not found');
    final visit = _visits[i];

    if ((action == QueueAction.ready || action == QueueAction.transfer) &&
        (_config.receptionZoomUrl.isEmpty || _config.attorneyZoomUrl.isEmpty)) {
      throw StateError(
        'Zoom meetings are not configured. Contact an Admin to set reception and attorney Zoom URLs.',
      );
    }

    final next = switch (action) {
      QueueAction.ready => VisitStatus.ready,
      QueueAction.transfer => VisitStatus.withAttorney,
      QueueAction.complete => VisitStatus.completed,
      QueueAction.dismiss => VisitStatus.dismissed,
    };
    _visits[i] = visit.copyWith(status: next);
    return _delay(_visits[i]);
  }

  Future<LobbyConfig> toggleLobby(bool open) async {
    _config = _config.copyWith(isOpen: open);
    return _delay(_config);
  }

  // —— Admin ——

  Future<LobbyConfig> getAdminSettings() => getConfig();

  Future<LobbyConfig> updateAdminSettings(LobbyConfig settings) async {
    _config = settings;
    return _delay(_config);
  }

  Future<List<StaffUser>> listStaff() => _delay(List.unmodifiable(_staff));

  Future<StaffUser> createReceptionist({
    required String username,
    required String email,
    required String temporaryPassword,
  }) async {
    if (_staff.any((s) => s.username == username)) {
      throw StateError('Username already exists');
    }
    final user = StaffUser(
      id: _uuid.v4(),
      username: username,
      email: email,
      displayName: username,
      role: AppRole.receptionist,
      capabilities: const ['alf_manage_lobby'],
    );
    _staff.add(user);
    _passwords[username] = temporaryPassword;
    return _delay(user);
  }

  Future<StaffUser> resetReceptionistPassword(
    String staffId,
    String temporaryPassword,
  ) async {
    final user = _staff.firstWhere((s) => s.id == staffId);
    _passwords[user.username] = temporaryPassword;
    return _delay(user);
  }

  Future<StaffUser> setStaffActive(String staffId, bool active) async {
    final i = _staff.indexWhere((s) => s.id == staffId);
    if (i < 0) throw StateError('Staff not found');
    if (_staff[i].role == AppRole.admin) {
      throw StateError('Cannot deactivate admin from the app');
    }
    _staff[i] = _staff[i].copyWith(active: active);
    return _delay(_staff[i]);
  }
}
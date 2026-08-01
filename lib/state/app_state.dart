import 'package:flutter/foundation.dart';

import '../models/models.dart';
import '../rbac/roles.dart';
import '../services/mock_api.dart';
import '../services/session_storage.dart';

enum AppPath { undecided, client, staff }

class AppState extends ChangeNotifier {
  AppState({
    MockApi? api,
    SessionStorage? storage,
  })  : api = api ?? MockApi(),
        storage = storage ?? SessionStorage();

  final MockApi api;
  final SessionStorage storage;

  bool bootstrapped = false;
  AppPath path = AppPath.undecided;
  AuthSession? staffSession;
  ClientSession? clientSession;
  LobbyConfig? config;
  Visit? activeVisit;
  List<Visit> queue = [];
  List<StaffUser> staffUsers = [];
  String? error;

  // Client wizard draft
  String draftName = '';
  String draftPhone = '';
  String draftCountry = '+1';
  String draftMatter = '';

  AppRole? get role => staffSession?.user.role;
  bool get isAdmin => role == AppRole.admin;
  bool get isReceptionist =>
      role == AppRole.receptionist || role == AppRole.admin;
  bool can(Capability c) =>
      role != null ? Rbac.can(role!, c) : false;

  Future<void> bootstrap() async {
    try {
      config = await api.getConfig();
      final token = await storage.getStaffAccessToken();
      if (token != null) {
        final user = await api.me(token);
        staffSession = AuthSession(
          accessToken: token,
          refreshToken: '',
          user: user,
        );
        path = AppPath.staff;
        await refreshQueue();
        if (isAdmin) await refreshStaff();
      } else {
        final client = await storage.getClientSession();
        if (client != null) {
          clientSession = client;
          path = AppPath.client;
          activeVisit = await api.getVisit(client.visitId, client.token);
        }
      }
    } catch (_) {
      await storage.clearStaffSession();
      await storage.clearClientSession();
    } finally {
      bootstrapped = true;
      notifyListeners();
    }
  }

  Future<void> refreshConfig() async {
    config = await api.getConfig();
    notifyListeners();
  }

  void chooseClient() {
    path = AppPath.client;
    notifyListeners();
  }

  void chooseStaff() {
    path = AppPath.staff;
    notifyListeners();
  }

  void backToLaunch() {
    path = AppPath.undecided;
    notifyListeners();
  }

  Future<void> staffLogin(String username, String password) async {
    error = null;
    notifyListeners();
    try {
      final session = await api.login(username.trim(), password);
      staffSession = session;
      path = AppPath.staff;
      await storage.saveStaffSession(session);
      await refreshQueue();
      if (isAdmin) await refreshStaff();
      notifyListeners();
    } catch (e) {
      error = e.toString().replaceFirst('Bad state: ', '');
      notifyListeners();
      rethrow;
    }
  }

  Future<void> staffLogout() async {
    staffSession = null;
    queue = [];
    await storage.clearStaffSession();
    path = AppPath.undecided;
    notifyListeners();
  }

  Future<void> clientLogout() async {
    activeVisit = null;
    clientSession = null;
    draftName = '';
    draftPhone = '';
    draftMatter = '';
    await storage.clearClientSession();
    path = AppPath.undecided;
    notifyListeners();
  }

  Future<Visit> submitCheckIn() async {
    final phone = draftCountry == '+1'
        ? '+1${draftPhone.replaceAll(RegExp(r'\D'), '')}'
        : '+91${draftPhone.replaceAll(RegExp(r'\D'), '')}';
    final visit = await api.checkIn(
      fullName: draftName,
      phone: phone,
      matter: draftMatter,
    );
    activeVisit = visit;
    clientSession = ClientSession(visitId: visit.id, token: visit.token);
    await storage.saveClientSession(clientSession!);
    await refreshConfig();
    notifyListeners();
    return visit;
  }

  Future<void> pollVisit() async {
    final session = clientSession;
    if (session == null) return;
    activeVisit = await api.getVisit(session.visitId, session.token);
    notifyListeners();
  }

  Future<void> markJoined() async {
    final session = clientSession;
    if (session == null) return;
    activeVisit = await api.markJoined(session.visitId, session.token);
    notifyListeners();
  }

  Future<void> refreshQueue() async {
    queue = await api.getQueue();
    config = await api.getConfig();
    notifyListeners();
  }

  Future<void> runQueueAction(String visitId, QueueAction action) async {
    await api.queueAction(visitId, action);
    await refreshQueue();
  }

  Future<void> setLobbyOpen(bool open) async {
    config = await api.toggleLobby(open);
    notifyListeners();
  }

  Future<void> refreshStaff() async {
    staffUsers = await api.listStaff();
    notifyListeners();
  }

  Future<void> saveAdminSettings(LobbyConfig settings) async {
    config = await api.updateAdminSettings(settings);
    notifyListeners();
  }

  Future<void> createReceptionist({
    required String username,
    required String email,
    required String password,
  }) async {
    await api.createReceptionist(
      username: username,
      email: email,
      temporaryPassword: password,
    );
    await refreshStaff();
  }

  Future<void> deactivateStaff(String id) async {
    await api.setStaffActive(id, false);
    await refreshStaff();
  }
}
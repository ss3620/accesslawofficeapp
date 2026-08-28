enum SenderRole {
  client,
  receptionist,
  attorney,
  system;

  String get label => switch (this) {
        SenderRole.client => 'You',
        SenderRole.receptionist => 'Reception',
        SenderRole.attorney => 'Attorney',
        SenderRole.system => 'Access Law Firm',
      };

  static SenderRole fromName(String value) {
    return SenderRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => SenderRole.system,
    );
  }
}

enum StaffRole {
  receptionist,
  attorney,
  admin;

  String get label => switch (this) {
        StaffRole.receptionist => 'Receptionist',
        StaffRole.attorney => 'Attorney',
        StaffRole.admin => 'Admin',
      };

  SenderRole get senderRole => switch (this) {
        StaffRole.attorney => SenderRole.attorney,
        _ => SenderRole.receptionist,
      };

  static StaffRole fromName(String value) {
    return StaffRole.values.firstWhere(
      (r) => r.name == value,
      orElse: () => StaffRole.receptionist,
    );
  }
}

/// Client position in the video lobby. Mirrors the receptionist -> attorney
/// handoff the firm uses instead of Zoom breakout rooms.
enum LobbyStatus {
  idle,
  waiting,
  ready,
  withAttorney,
  completed;

  String get label => switch (this) {
        LobbyStatus.idle => 'Not in lobby',
        LobbyStatus.waiting => 'Waiting',
        LobbyStatus.ready => 'Reception ready',
        LobbyStatus.withAttorney => 'Attorney ready',
        LobbyStatus.completed => 'Completed',
      };

  static LobbyStatus fromName(String value) {
    return LobbyStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => LobbyStatus.idle,
    );
  }
}

enum AppointmentStatus {
  requested,
  confirmed,
  declined;

  String get label => switch (this) {
        AppointmentStatus.requested => 'Requested',
        AppointmentStatus.confirmed => 'Confirmed',
        AppointmentStatus.declined => 'Declined',
      };

  static AppointmentStatus fromName(String value) {
    return AppointmentStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => AppointmentStatus.requested,
    );
  }
}

class ClientProfile {
  const ClientProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.threadId,
    required this.active,
    required this.activationCode,
    required this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String threadId;
  final bool active;
  final String activationCode;
  final DateTime createdAt;

  factory ClientProfile.fromMap(String id, Map<String, dynamic> map) {
    return ClientProfile(
      id: id,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      threadId: (map['threadId'] ?? id) as String,
      active: (map['active'] ?? true) as bool,
      activationCode: (map['activationCode'] ?? '') as String,
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'threadId': threadId,
        'active': active,
        'activationCode': activationCode,
        'createdAt': createdAt.toIso8601String(),
      };
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.body,
    required this.createdAt,
    this.urgent = false,
  });

  final String id;
  final String senderId;
  final SenderRole senderRole;
  final String senderName;
  final String body;
  final DateTime createdAt;
  final bool urgent;

  factory ChatMessage.fromMap(String id, Map<String, dynamic> map) {
    return ChatMessage(
      id: id,
      senderId: (map['senderId'] ?? '') as String,
      senderRole: SenderRole.fromName((map['senderRole'] ?? 'system') as String),
      senderName: (map['senderName'] ?? '') as String,
      body: (map['body'] ?? '') as String,
      createdAt: _toDate(map['createdAt']),
      urgent: (map['urgent'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toMap() => {
        'senderId': senderId,
        'senderRole': senderRole.name,
        'senderName': senderName,
        'body': body,
        'urgent': urgent,
      };
}

class LobbyState {
  const LobbyState({
    required this.clientId,
    required this.status,
    required this.receptionZoomUrl,
    required this.attorneyZoomUrl,
    required this.updatedAt,
    this.position = 0,
  });

  final String clientId;
  final LobbyStatus status;
  final String receptionZoomUrl;
  final String attorneyZoomUrl;
  final DateTime updatedAt;
  final int position;

  bool get canJoinReception =>
      status == LobbyStatus.ready && receptionZoomUrl.isNotEmpty;
  bool get canJoinAttorney =>
      status == LobbyStatus.withAttorney && attorneyZoomUrl.isNotEmpty;

  factory LobbyState.empty(String clientId) => LobbyState(
        clientId: clientId,
        status: LobbyStatus.idle,
        receptionZoomUrl: '',
        attorneyZoomUrl: '',
        updatedAt: DateTime.now(),
      );

  factory LobbyState.fromMap(String clientId, Map<String, dynamic> map) {
    return LobbyState(
      clientId: clientId,
      status: LobbyStatus.fromName((map['status'] ?? 'idle') as String),
      receptionZoomUrl: (map['receptionZoomUrl'] ?? '') as String,
      attorneyZoomUrl: (map['attorneyZoomUrl'] ?? '') as String,
      updatedAt: _toDate(map['updatedAt']),
      position: (map['position'] ?? 0) as int,
    );
  }

  LobbyState copyWith({
    LobbyStatus? status,
    String? receptionZoomUrl,
    String? attorneyZoomUrl,
    int? position,
  }) {
    return LobbyState(
      clientId: clientId,
      status: status ?? this.status,
      receptionZoomUrl: receptionZoomUrl ?? this.receptionZoomUrl,
      attorneyZoomUrl: attorneyZoomUrl ?? this.attorneyZoomUrl,
      updatedAt: DateTime.now(),
      position: position ?? this.position,
    );
  }
}

class AppointmentRequest {
  const AppointmentRequest({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.preferredWindow,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String clientId;
  final String clientName;
  final String preferredWindow;
  final String note;
  final AppointmentStatus status;
  final DateTime createdAt;

  factory AppointmentRequest.fromMap(String id, Map<String, dynamic> map) {
    return AppointmentRequest(
      id: id,
      clientId: (map['clientId'] ?? '') as String,
      clientName: (map['clientName'] ?? '') as String,
      preferredWindow: (map['preferredWindow'] ?? '') as String,
      note: (map['note'] ?? '') as String,
      status:
          AppointmentStatus.fromName((map['status'] ?? 'requested') as String),
      createdAt: _toDate(map['createdAt']),
    );
  }

  Map<String, dynamic> toMap() => {
        'clientId': clientId,
        'clientName': clientName,
        'preferredWindow': preferredWindow,
        'note': note,
        'status': status.name,
      };
}

class ActivationCode {
  const ActivationCode({
    required this.code,
    required this.email,
    required this.used,
    required this.createdAt,
    this.clientId,
  });

  final String code;
  final String email;
  final bool used;
  final DateTime createdAt;
  final String? clientId;

  factory ActivationCode.fromMap(String code, Map<String, dynamic> map) {
    return ActivationCode(
      code: code,
      email: (map['email'] ?? '') as String,
      used: (map['used'] ?? false) as bool,
      createdAt: _toDate(map['createdAt']),
      clientId: map['clientId'] as String?,
    );
  }
}

/// WordPress Virtual Lobby queue row (`alf_lobby_visit`) — website or app.
enum QueueVisitStatus {
  waiting,
  ready,
  inMeeting,
  withAttorney;

  String get label => switch (this) {
        QueueVisitStatus.waiting => 'Waiting',
        QueueVisitStatus.ready => 'Reception ready',
        QueueVisitStatus.inMeeting => 'In reception',
        QueueVisitStatus.withAttorney => 'Attorney ready',
      };

  static QueueVisitStatus fromWordPress(String value) {
    return switch (value) {
      'ready' => QueueVisitStatus.ready,
      'in_meeting' => QueueVisitStatus.inMeeting,
      'with_attorney' => QueueVisitStatus.withAttorney,
      _ => QueueVisitStatus.waiting,
    };
  }
}

class QueueVisit {
  const QueueVisit({
    required this.id,
    required this.name,
    required this.phone,
    required this.matter,
    required this.status,
    required this.statusLabel,
    required this.positionLabel,
    required this.waitLabel,
    this.appClientId,
  });

  final int id;
  final String name;
  final String phone;
  final String matter;
  final QueueVisitStatus status;
  final String statusLabel;
  final String positionLabel;
  final String waitLabel;
  final String? appClientId;

  bool get isAppClient => appClientId != null && appClientId!.isNotEmpty;

  factory QueueVisit.fromMap(Map<String, dynamic> map) {
    final position = map['position'];
    return QueueVisit(
      id: (map['id'] as num).toInt(),
      name: (map['name'] ?? '') as String,
      phone: (map['phone'] ?? '—') as String,
      matter: (map['matter'] ?? '') as String,
      status: QueueVisitStatus.fromWordPress((map['status'] ?? 'waiting') as String),
      statusLabel: (map['status_label'] ?? map['status'] ?? '') as String,
      positionLabel: position is num ? '#${position.toInt()}' : (position?.toString() ?? '—'),
      waitLabel: (map['wait'] ?? '') as String,
      appClientId: map['app_client_id'] as String?,
    );
  }
}

class LobbyQueueSnapshot {
  const LobbyQueueSnapshot({
    required this.items,
    required this.lobbyOpen,
  });

  final List<QueueVisit> items;
  final bool lobbyOpen;

  factory LobbyQueueSnapshot.empty() =>
      const LobbyQueueSnapshot(items: [], lobbyOpen: true);

  factory LobbyQueueSnapshot.fromMap(Map<String, dynamic> map) {
    final items = (map['items'] as List<dynamic>? ?? const [])
        .map((raw) => QueueVisit.fromMap(raw as Map<String, dynamic>))
        .toList();
    return LobbyQueueSnapshot(
      items: items,
      lobbyOpen: (map['lobby_open'] ?? true) as bool,
    );
  }
}

class StaffProfile {
  const StaffProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  final String id;
  final String name;
  final String email;
  final StaffRole role;

  bool get canConfigure => role == StaffRole.admin;

  factory StaffProfile.fromMap(String id, Map<String, dynamic> map) {
    return StaffProfile(
      id: id,
      name: (map['name'] ?? '') as String,
      email: (map['email'] ?? '') as String,
      role: StaffRole.fromName((map['role'] ?? 'receptionist') as String),
    );
  }
}

DateTime _toDate(Object? value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  // Firestore Timestamp exposes toDate() without importing the package here.
  try {
    return (value as dynamic).toDate() as DateTime;
  } catch (_) {
    return DateTime.now();
  }
}

import '../rbac/roles.dart';

enum VisitStatus {
  waiting,
  ready,
  inMeeting,
  withAttorney,
  completed,
  dismissed;

  String get label => switch (this) {
        VisitStatus.waiting => 'Waiting',
        VisitStatus.ready => 'Ready',
        VisitStatus.inMeeting => 'In reception',
        VisitStatus.withAttorney => 'With attorney',
        VisitStatus.completed => 'Completed',
        VisitStatus.dismissed => 'Dismissed',
      };

  static VisitStatus fromApi(String value) {
    return switch (value) {
      'waiting' => VisitStatus.waiting,
      'ready' => VisitStatus.ready,
      'in_meeting' => VisitStatus.inMeeting,
      'with_attorney' => VisitStatus.withAttorney,
      'completed' => VisitStatus.completed,
      'dismissed' => VisitStatus.dismissed,
      _ => VisitStatus.waiting,
    };
  }

  String get apiValue => switch (this) {
        VisitStatus.waiting => 'waiting',
        VisitStatus.ready => 'ready',
        VisitStatus.inMeeting => 'in_meeting',
        VisitStatus.withAttorney => 'with_attorney',
        VisitStatus.completed => 'completed',
        VisitStatus.dismissed => 'dismissed',
      };
}

enum VerifyMode { sms, captcha, smsCaptcha, none }

enum QueueAction { ready, transfer, complete, dismiss }

class LobbyConfig {
  const LobbyConfig({
    required this.isOpen,
    required this.waitingCount,
    required this.hoursCopy,
    required this.verifyMode,
    required this.matters,
    required this.receptionZoomUrl,
    required this.attorneyZoomUrl,
    required this.receptionMeetingNumber,
    required this.attorneyMeetingNumber,
    required this.receptionPasscode,
    required this.attorneyPasscode,
    required this.featureMessaging,
    required this.featureVoip,
    required this.featureMeetingSdk,
  });

  final bool isOpen;
  final int waitingCount;
  final String hoursCopy;
  final VerifyMode verifyMode;
  final List<String> matters;
  final String receptionZoomUrl;
  final String attorneyZoomUrl;
  final String receptionMeetingNumber;
  final String attorneyMeetingNumber;
  final String receptionPasscode;
  final String attorneyPasscode;
  final bool featureMessaging;
  final bool featureVoip;
  final bool featureMeetingSdk;

  LobbyConfig copyWith({
    bool? isOpen,
    int? waitingCount,
    String? hoursCopy,
    VerifyMode? verifyMode,
    List<String>? matters,
    String? receptionZoomUrl,
    String? attorneyZoomUrl,
    String? receptionMeetingNumber,
    String? attorneyMeetingNumber,
    String? receptionPasscode,
    String? attorneyPasscode,
    bool? featureMessaging,
    bool? featureVoip,
    bool? featureMeetingSdk,
  }) {
    return LobbyConfig(
      isOpen: isOpen ?? this.isOpen,
      waitingCount: waitingCount ?? this.waitingCount,
      hoursCopy: hoursCopy ?? this.hoursCopy,
      verifyMode: verifyMode ?? this.verifyMode,
      matters: matters ?? this.matters,
      receptionZoomUrl: receptionZoomUrl ?? this.receptionZoomUrl,
      attorneyZoomUrl: attorneyZoomUrl ?? this.attorneyZoomUrl,
      receptionMeetingNumber:
          receptionMeetingNumber ?? this.receptionMeetingNumber,
      attorneyMeetingNumber: attorneyMeetingNumber ?? this.attorneyMeetingNumber,
      receptionPasscode: receptionPasscode ?? this.receptionPasscode,
      attorneyPasscode: attorneyPasscode ?? this.attorneyPasscode,
      featureMessaging: featureMessaging ?? this.featureMessaging,
      featureVoip: featureVoip ?? this.featureVoip,
      featureMeetingSdk: featureMeetingSdk ?? this.featureMeetingSdk,
    );
  }
}

class Visit {
  const Visit({
    required this.id,
    required this.token,
    required this.fullName,
    required this.phone,
    required this.matter,
    required this.status,
    required this.position,
    required this.createdAt,
    this.joinedAt,
  });

  final String id;
  final String token;
  final String fullName;
  final String phone;
  final String matter;
  final VisitStatus status;
  final int position;
  final DateTime createdAt;
  final DateTime? joinedAt;

  String get maskedPhone {
    if (phone.length < 4) return phone;
    return '••••${phone.substring(phone.length - 4)}';
  }

  Duration get waitDuration => DateTime.now().difference(createdAt);

  Visit copyWith({
    String? id,
    String? token,
    String? fullName,
    String? phone,
    String? matter,
    VisitStatus? status,
    int? position,
    DateTime? createdAt,
    DateTime? joinedAt,
  }) {
    return Visit(
      id: id ?? this.id,
      token: token ?? this.token,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      matter: matter ?? this.matter,
      status: status ?? this.status,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      joinedAt: joinedAt ?? this.joinedAt,
    );
  }
}

class StaffUser {
  const StaffUser({
    required this.id,
    required this.username,
    required this.email,
    required this.displayName,
    required this.role,
    required this.capabilities,
    this.active = true,
  });

  final String id;
  final String username;
  final String email;
  final String displayName;
  final AppRole role;
  final List<String> capabilities;
  final bool active;

  StaffUser copyWith({bool? active}) {
    return StaffUser(
      id: id,
      username: username,
      email: email,
      displayName: displayName,
      role: role,
      capabilities: capabilities,
      active: active ?? this.active,
    );
  }
}

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String refreshToken;
  final StaffUser user;
}

class ClientSession {
  const ClientSession({
    required this.visitId,
    required this.token,
  });

  final String visitId;
  final String token;
}
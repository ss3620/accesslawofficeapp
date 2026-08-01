enum AppRole {
  client,
  receptionist,
  admin;

  String get label => switch (this) {
        AppRole.client => 'Client',
        AppRole.receptionist => 'Receptionist',
        AppRole.admin => 'Admin',
      };

  /// WordPress mapping for staff roles.
  String get wordpressRole => switch (this) {
        AppRole.client => 'guest',
        AppRole.receptionist => 'alf_receptionist',
        AppRole.admin => 'administrator',
      };
}

enum Capability {
  joinLobby,
  viewOwnVisit,
  messageOwnThread,
  viewQueue,
  queueActions,
  toggleLobby,
  placeCall,
  viewVisitDetails,
  configureZoom,
  configureTwilio,
  manageFeatureFlags,
  manageStaff,
  viewReports,
}

abstract final class Rbac {
  static const Map<AppRole, Set<Capability>> matrix = {
    AppRole.client: {
      Capability.joinLobby,
      Capability.viewOwnVisit,
      Capability.messageOwnThread,
    },
    AppRole.receptionist: {
      Capability.messageOwnThread,
      Capability.viewQueue,
      Capability.queueActions,
      Capability.toggleLobby,
      Capability.placeCall,
      Capability.viewVisitDetails,
    },
    AppRole.admin: {
      Capability.messageOwnThread,
      Capability.viewQueue,
      Capability.queueActions,
      Capability.toggleLobby,
      Capability.placeCall,
      Capability.viewVisitDetails,
      Capability.configureZoom,
      Capability.configureTwilio,
      Capability.manageFeatureFlags,
      Capability.manageStaff,
      Capability.viewReports,
    },
  };

  static bool can(AppRole role, Capability capability) {
    return matrix[role]?.contains(capability) ?? false;
  }

  static AppRole? fromCapabilities(List<String> caps) {
    if (caps.contains('manage_options')) return AppRole.admin;
    if (caps.contains('alf_manage_lobby')) return AppRole.receptionist;
    return null;
  }
}
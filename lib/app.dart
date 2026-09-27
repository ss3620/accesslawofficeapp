import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/client/activation_screen.dart';
import 'screens/client/appointment_screen.dart';
import 'screens/client/chat_screen.dart';
import 'screens/client/client_home_screen.dart';
import 'screens/client/video_lobby_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/staff/staff_client_detail_screen.dart';
import 'screens/staff/staff_home_screen.dart';
import 'screens/staff/staff_login_screen.dart';
import 'screens/staff/staff_settings_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

abstract final class Routes {
  static const splash = '/';
  static const activation = '/activate';
  static const clientHome = '/client';
  static const chat = '/client/chat';
  static const videoLobby = '/client/lobby';
  static const appointment = '/client/appointment';
  static const staffLogin = '/staff/login';
  static const staffHome = '/staff';
  static const staffClient = '/staff/client';
  static const staffSettings = '/staff/settings';
}

/// Used by push tap handlers to open the right screen.
final GlobalKey<NavigatorState> alfNavigatorKey = GlobalKey<NavigatorState>();

class AccessLawApp extends StatefulWidget {
  const AccessLawApp({super.key});

  @override
  State<AccessLawApp> createState() => _AccessLawAppState();
}

class _AccessLawAppState extends State<AccessLawApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      state.push.onOpened = ({String? type, String? threadId}) {
        _openFromPush(state, type: type);
      };
    });
  }

  void _openFromPush(
    AppState state, {
    String? type,
  }) {
    final nav = alfNavigatorKey.currentState;
    if (nav == null) return;

    if (type == 'lobby_waiting' && state.staff != null) {
      nav.pushNamedAndRemoveUntil(Routes.staffHome, (route) => false);
      return;
    }

    if (type == 'lobby' && state.client != null) {
      nav.pushNamedAndRemoveUntil(Routes.clientHome, (route) => false);
      nav.pushNamed(Routes.videoLobby);
      return;
    }

    if (type == 'message') {
      if (state.staff != null) {
        nav.pushNamedAndRemoveUntil(Routes.staffHome, (route) => false);
      } else if (state.client != null) {
        nav.pushNamedAndRemoveUntil(Routes.clientHome, (route) => false);
        nav.pushNamed(Routes.chat);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Access Law Firm',
      navigatorKey: alfNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: Routes.splash,
      routes: {
        Routes.splash: (_) => const SplashScreen(),
        Routes.activation: (_) => const ActivationScreen(),
        Routes.clientHome: (_) => const ClientHomeScreen(),
        Routes.chat: (_) => const ChatScreen(),
        Routes.videoLobby: (_) => const VideoLobbyScreen(),
        Routes.appointment: (_) => const AppointmentScreen(),
        Routes.staffLogin: (_) => const StaffLoginScreen(),
        Routes.staffHome: (_) => const StaffHomeScreen(),
        Routes.staffClient: (_) => const StaffClientDetailScreen(),
        Routes.staffSettings: (_) => const StaffSettingsScreen(),
      },
    );
  }
}

/// Sends the user to the right home after bootstrap or a sign-out.
String routeForSession(AppState state) {
  return switch (state.sessionKind) {
    SessionKind.client => Routes.clientHome,
    SessionKind.staff => Routes.staffHome,
    SessionKind.none => Routes.activation,
  };
}

void goHome(BuildContext context) {
  final state = context.read<AppState>();
  Navigator.of(context).pushNamedAndRemoveUntil(
    routeForSession(state),
    (route) => false,
  );
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/admin/admin_home_screen.dart';
import 'screens/admin/admin_settings_screen.dart';
import 'screens/admin/staff_users_screen.dart';
import 'screens/client/lobby_home_screen.dart';
import 'screens/client/matter_screen.dart';
import 'screens/client/name_screen.dart';
import 'screens/client/phone_screen.dart';
import 'screens/client/verify_screen.dart';
import 'screens/client/waiting_screen.dart';
import 'screens/launch_screen.dart';
import 'screens/receptionist/queue_screen.dart';
import 'screens/staff_login_screen.dart';
import 'screens/staff_profile_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

class AccessLawApp extends StatelessWidget {
  const AccessLawApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Access Law Firm',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: '/bootstrap',
      routes: {
        '/bootstrap': (_) => const _BootstrapGate(),
        '/': (_) => const LaunchScreen(),
        '/client/home': (_) => const LobbyHomeScreen(),
        '/client/name': (_) => const NameScreen(),
        '/client/phone': (_) => const PhoneScreen(),
        '/client/verify': (_) => const VerifyScreen(),
        '/client/matter': (_) => const MatterScreen(),
        '/client/waiting': (_) => const WaitingScreen(),
        '/staff/login': (_) => const StaffLoginScreen(),
        '/staff/profile': (_) => const StaffProfileScreen(),
        '/receptionist/queue': (_) => const QueueScreen(),
        '/admin/home': (_) => const AdminHomeScreen(),
        '/admin/settings': (_) => const AdminSettingsScreen(),
        '/admin/staff': (_) => const StaffUsersScreen(),
      },
    );
  }
}

class _BootstrapGate extends StatefulWidget {
  const _BootstrapGate();

  @override
  State<_BootstrapGate> createState() => _BootstrapGateState();
}

class _BootstrapGateState extends State<_BootstrapGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final app = context.read<AppState>();
      await app.bootstrap();
      if (!mounted) return;
      if (app.staffSession != null) {
        final route = app.isAdmin ? '/admin/home' : '/receptionist/queue';
        Navigator.of(context).pushReplacementNamed(route);
      } else if (app.activeVisit != null) {
        Navigator.of(context).pushReplacementNamed('/client/waiting');
      } else {
        Navigator.of(context).pushReplacementNamed('/');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1C4F94),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SplashBrand(),
            SizedBox(height: 28),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: Color(0xFFC4A35A),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
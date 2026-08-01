import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../theme/colors.dart';
import '../widgets/common.dart';

class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.navy,
              AppColors.navyMid,
              Color(0xFF0A1628),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 36, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BrandHeader(light: true),
                const Spacer(),
                Text(
                  'Virtual Lobby',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        color: Colors.white,
                        fontSize: 36,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Join from your phone, wait for our receptionist, then meet virtually — without leaving the app.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                ),
                const SizedBox(height: 36),
                PrimaryButton(
                  label: 'Join Virtual Lobby',
                  gold: true,
                  onPressed: () {
                    context.read<AppState>().chooseClient();
                    Navigator.of(context).pushNamed('/client/home');
                  },
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      context.read<AppState>().chooseStaff();
                      Navigator.of(context).pushNamed('/staff/login');
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    child: const Text('Staff sign in'),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Houston · Immigration Law',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.goldLight.withValues(alpha: 0.85),
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
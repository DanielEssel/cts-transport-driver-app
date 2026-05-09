// lib/features/root/driver_root_shell.dart

import 'package:flutter/material.dart';
import '../../app/app_theme.dart';
import '../../features/driver/presentation/screens/driver_home_screen.dart';
import '../earnings/presentation/screens/earning_screen.dart';
import '../wallet/presentation/screens/driver_wallet_screen.dart';
import '../profile/presentation/screens/driver_profile_screen.dart';
import '../../features/driver/models/driver_types.dart';

class DriverRootShell extends StatefulWidget {
  final DriverProfile profile;

  const DriverRootShell({super.key, required this.profile});

  @override
  State<DriverRootShell> createState() => _DriverRootShellState();
}

class _DriverRootShellState extends State<DriverRootShell> {
  int _currentIndex = 0;
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DriverHomeScreen(profile: widget.profile),
      const EarningsScreen(),
      const DriverWalletScreen(),
      const DriverProfileScreen(),];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.divider, width: 1)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          selectedItemColor: AppTheme.primary,
          unselectedItemColor: AppTheme.textSecondary,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_outlined),
              activeIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_outlined),
              activeIcon: Icon(Icons.bar_chart_rounded),
              label: 'Earnings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.account_balance_wallet_outlined),
              activeIcon: Icon(Icons.account_balance_wallet_rounded),
              label: 'Wallet',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
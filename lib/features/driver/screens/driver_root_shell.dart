import 'package:flutter/material.dart';
import '../models/driver_type.dart';
import '../theme/app_theme.dart';
import 'driver_home_screen.dart';
import 'earnings_screen.dart';
import 'driver_wallet_screen.dart';
import 'driver_profile_screen.dart';

class DriverRootShell extends StatefulWidget {
  final DriverType driverType;

  const DriverRootShell({super.key, required this.driverType});

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
      DriverHomeScreen(driverType: widget.driverType),
      const EarningsScreen(),
      const DriverWalletScreen(),
      DriverProfileScreen(driverType: widget.driverType),
    ];
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
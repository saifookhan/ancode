import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'my_codes_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 2; // Search (Dashboard, Create, Search, Profile)
  final _screens = const [
    MyCodesScreen(),
    CreateScreen(),
    HomeScreen(),
    ProfileScreen(),
  ];

  static const int _searchIndex = 2;

  void _onBottomNavTap(int i) {
    if (i == _searchIndex) {
      setState(() => _currentIndex = _searchIndex);
      return;
    }
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }
    setState(() => _currentIndex = i);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: AncodeBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }
}

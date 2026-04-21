import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'chatbot_screen.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'profile_placeholder_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0; // Home, Dashboard, Crea, Chatbot, Profilo

  late final List<Widget> _screens = <Widget>[
    const HomeScreen(),
    const ProfileScreen(),
    const CreateScreen(),
    const ChatbotScreen(),
    const ProfilePlaceholderScreen(),
  ];

  static const int _homeIndex = 0;
  static const int createIndex = 2;
  static const int _createIndex = 2;

  void goToTab(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  void _onBottomNavTap(int i) {
    if (i == _homeIndex) {
      goToTab(i);
      return;
    }
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      );
      return;
    }
    goToTab(i);
  }

  @override
  Widget build(BuildContext context) {
    final shellBackground = _currentIndex == _createIndex ? AppColors.bluUniverso : AppColors.biancoOttico;
    return Scaffold(
      backgroundColor: shellBackground,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: AncodeBottomNavBar(
        currentIndex: _currentIndex,
        onTap: _onBottomNavTap,
      ),
    );
  }
}

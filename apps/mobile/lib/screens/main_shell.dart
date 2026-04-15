import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import '../services/siri_shortcut_service.dart';
import 'auth/login_screen.dart';
import 'create_screen.dart';
import 'history_screen.dart';
import 'home_screen.dart';
import 'my_codes_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 1; // History, Search, Create, Dashboard
  StreamSubscription<String>? _siriSubscription;
  final _screens = const [
    HistoryScreen(),
    HomeScreen(),
    CreateScreen(),
    MyCodesScreen(),
  ];

  static const int _searchIndex = 1;

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
  void initState() {
    super.initState();
    _siriSubscription = SiriShortcutService.instance.searchCodeStream.listen((_) {
      if (!mounted || _currentIndex == _searchIndex) return;
      setState(() => _currentIndex = _searchIndex);
    });
  }

  @override
  void dispose() {
    _siriSubscription?.cancel();
    super.dispose();
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

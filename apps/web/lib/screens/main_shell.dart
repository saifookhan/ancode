import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'chatbot_screen.dart';
import 'create_screen.dart';
import 'home_screen.dart';
import 'edit_profile_screen.dart';
import 'profile_screen.dart';
import 'profile_placeholder_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  /// Opens on Home (search); tab order is Crea, Dashboard, Home, …
  int _currentIndex = 2;

  final GlobalKey<ProfileScreenState> _dashboardKey = GlobalKey<ProfileScreenState>();
  final GlobalKey<ProfilePlaceholderScreenState> _profileKey =
      GlobalKey<ProfilePlaceholderScreenState>();
  late final List<Widget> _screens;

  static const int _homeTabIndex = 2;
  static const int _dashboardIndex = 1;
  /// Bottom-nav index for Dashboard (same as [_dashboardIndex]).
  static const int dashboardTabIndex = 1;
  /// Bottom-nav index for Profilo ([ProfilePlaceholderScreen]).
  static const int profileTabIndex = 4;
  static const int createIndex = 0;
  static const int _createIndex = 0;

  void _goHomeFromHeader() => goToTab(_homeTabIndex);

  void _openEditProfileFromHeader() {
    if (!mounted) return;
    unawaited(
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(builder: (_) => const EditProfileScreen()),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      const CreateScreen(),
      ProfileScreen(
        key: _dashboardKey,
        onAppHeaderLogoTap: _goHomeFromHeader,
        onAppHeaderProfileTap: _openEditProfileFromHeader,
      ),
      const HomeScreen(),
      const ChatbotScreen(),
      ProfilePlaceholderScreen(
        key: _profileKey,
        onAppHeaderLogoTap: _goHomeFromHeader,
        onAppHeaderProfileTap: _openEditProfileFromHeader,
      ),
    ];
  }

  void goToTab(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
    if (index == _dashboardIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _dashboardKey.currentState?.reloadDashboardStats();
      });
    }
    if (index == profileTabIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_profileKey.currentState?.reloadCodesCount() ?? Future<void>.value());
      });
    }
  }

  /// Refetch Dashboard codici + chart (e.g. after creating a code on the Crea tab).
  void refreshDashboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _dashboardKey.currentState?.reloadDashboardStats();
    });
  }

  /// Refetch Profilo "Codici attivi" counter (e.g. after creating a code).
  void refreshProfileCodesUsage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_profileKey.currentState?.reloadCodesCount() ?? Future<void>.value());
    });
  }

  void _onBottomNavTap(int i) {
    if (i == _homeTabIndex) {
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
    final shellBackground =
        _currentIndex == _createIndex ? AppColors.creaScreenBackground : AppColors.biancoOttico;
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

import 'package:flutter/material.dart';

import '../widgets/bottom_nav_bar.dart';
import 'home_screen.dart';
import 'history_screen.dart';
import 'create_screen.dart';
import 'my_codes_screen.dart';
import 'chatbot_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 2; // Search (matches nav order: History, Create, Search, Codes, Chatbot)
  final _screens = const [
    HistoryScreen(),
    CreateScreen(),
    HomeScreen(),
    MyCodesScreen(),
    ChatbotScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: AncodeBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'home_screen.dart';
import 'history_screen.dart';
import 'create_screen.dart';
import 'my_codes_screen.dart';
import 'chatbot_screen.dart';
import '../widgets/nav_bar.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 2; // Search (same order as mobile: History, Create, Search, Codes, Chatbot)

  final _screens = <Widget>[
    const HistoryScreen(),
    const CreateScreen(),
    const HomeScreen(),
    const MyCodesScreen(),
    const ChatbotScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: NavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

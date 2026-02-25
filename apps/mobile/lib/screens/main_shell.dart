import 'package:flutter/material.dart';

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
  int _currentIndex = 0;
  final _screens = const [
    HomeScreen(),
    HistoryScreen(),
    CreateScreen(),
    MyCodesScreen(),
    ChatbotScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Cerca o Crea',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Cronologia',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline),
            label: 'Crea',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'I miei codici',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'Chatbot',
          ),
        ],
      ),
    );
  }
}

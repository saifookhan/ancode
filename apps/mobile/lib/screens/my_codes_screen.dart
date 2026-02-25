import 'package:flutter/material.dart';

class MyCodesScreen extends StatelessWidget {
  const MyCodesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('I miei codici')),
      body: const Center(child: Text('I miei codici')),
    );
  }
}

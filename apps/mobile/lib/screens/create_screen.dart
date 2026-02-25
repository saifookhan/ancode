import 'package:flutter/material.dart';

class CreateScreen extends StatelessWidget {
  const CreateScreen({super.key, this.prefillCode});

  final String? prefillCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crea')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prefillCode != null && prefillCode!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Codice: $prefillCode', style: Theme.of(context).textTheme.titleMedium),
              ),
            const Text('Crea codice (form completo in seguito)'),
          ],
        ),
      ),
    );
  }
}

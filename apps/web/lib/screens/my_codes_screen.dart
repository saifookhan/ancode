import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import '../services/app_config.dart';
import 'create_screen.dart';

class MyCodesScreen extends StatefulWidget {
  const MyCodesScreen({super.key});

  @override
  State<MyCodesScreen> createState() => _MyCodesScreenState();
}

class _MyCodesScreenState extends State<MyCodesScreen> {
  List<Ancode> _codes = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      setState(() {
        _codes = [];
        _loading = false;
      });
      return;
    }
    try {
      final res = await Supabase.instance.client
          .from('ancodes')
          .select('*, municipality:municipalities(*)')
          .eq('owner_user_id', user.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _codes = (res as List)
              .map((r) => Ancode.fromJson({
                    ...r,
                    'municipality': r['municipality'] is Map ? r['municipality'] : null,
                  }))
              .toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() {
        _codes = [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(
      appBar: AppBar(
        title: const Text('I miei codici'),
        actions: [
          if (user != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateScreen()),
              ).then((_) => _load()),
            ),
        ],
      ),
      body: user == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.dashboard, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'Accedi per vedere i tuoi codici',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : _loading
              ? const Center(child: CircularProgressIndicator())
              : _codes.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.qr_code_2, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            'Nessun codice ancora',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const CreateScreen()),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Crea il primo'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _codes.length,
                        itemBuilder: (context, i) {
                          final c = _codes[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text('*${c.code}'),
                              subtitle: Text(
                                '${c.municipality?.name ?? c.municipalityId} • ${c.clickCount} clic',
                              ),
                              trailing: PopupMenuButton(
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'copy',
                                    child: ListTile(
                                      leading: Icon(Icons.copy),
                                      title: Text('Copia link'),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'test',
                                    child: ListTile(
                                      leading: Icon(Icons.open_in_new),
                                      title: Text('Testa'),
                                    ),
                                  ),
                                ],
                                onSelected: (v) {
                                  if (v == 'copy') {
                                    Clipboard.setData(ClipboardData(
                                      text: AppConfig.shortlinkFor(c.normalizedCode),
                                    ));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Link copiato')),
                                    );
                                  }
                                  if (v == 'test') {
                                    launchUrl(Uri.parse(
                                        AppConfig.shortlinkFor(c.normalizedCode)));
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

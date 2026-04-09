import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shared/shared.dart';

import '../services/app_config.dart';
import 'code_resolve_screen.dart';
import '../services/auth_service.dart';
import 'create_screen.dart';
import 'profile_screen.dart';

class MyCodesScreen extends StatefulWidget {
  const MyCodesScreen({super.key});

  @override
  State<MyCodesScreen> createState() => _MyCodesScreenState();
}

class _MyCodesScreenState extends State<MyCodesScreen> {
  List<Ancode> _codes = [];
  bool _loading = true;
  String? _error;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([String? forcedUserId]) async {
    final auth = context.read<AuthService>();
    final userId = forcedUserId ??
        Supabase.instance.client.auth.currentUser?.id ??
        auth.profile?.userId;
    if (userId == null || userId.isEmpty) {
      setState(() {
        _codes = [];
        _loading = false;
        _error = null;
        _lastUserId = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _fetchRowsForUser(userId);
      if (!mounted) return;
      setState(() {
        _codes = rows.map(_rowToAncode).toList();
        _loading = false;
        _lastUserId = userId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _codes = [];
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRowsForUser(String userId) async {
    try {
      final res = await Supabase.instance.client
          .from('codes')
          .select('*')
          .eq('created_by', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {}
    try {
      final res = await Supabase.instance.client
          .from('codes')
          .select('*')
          .eq('owner_user_id', userId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {}
    final res = await Supabase.instance.client
        .from('ancodes')
        .select('*, municipality:municipalities(*)')
        .eq('owner_user_id', userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(res);
  }

  Ancode _rowToAncode(Map<String, dynamic> r) {
    if (r['title'] != null) {
      final title = (r['title']?.toString() ?? '').trim();
      final contentType = (r['content_type']?.toString() ?? '').toLowerCase();
      final area = (r['area'] ?? r['content'])?.toString();
      return Ancode(
        id: (r['id']?.toString() ?? title),
        code: title,
        normalizedCode: normalizeCodeInput(title),
        type: contentType.contains('link') ? AncodeType.link : AncodeType.note,
        url: contentType.contains('link') ? area : null,
        noteText: contentType.contains('link') ? null : area,
        municipalityId: r['municipality_id']?.toString() ?? 'ALL',
        ownerUserId: (r['owner_user_id'] ?? r['created_by'] ?? '').toString(),
        isExclusiveItaly: r['is_exclusive_italy'] as bool? ?? false,
      );
    }
    return Ancode.fromJson({
      ...r,
      'municipality': r['municipality'] is Map ? r['municipality'] : null,
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? auth.profile?.userId;
    if (userId != null && userId.isNotEmpty && _lastUserId != userId && !_loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load(userId));
    }
    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      body: SafeArea(
        child: (userId == null || userId.isEmpty)
            ? const Center(
                child: Text(
                  'Accedi per vedere i tuoi codici',
                  style: TextStyle(color: AppColors.bluUniverso),
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      'Personal Area',
                      style: TextStyle(
                        color: Color(0xFF1E2230),
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const CreateScreen()),
                        ).then((_) => _load()),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Generate Ancode', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 56,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.edit),
                        label: const Text('Edit Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (_loading)
                      const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
                    else if (_error != null)
                      Text(_error!, style: const TextStyle(color: Colors.red))
                    else if (_codes.isEmpty)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('No codes yet', style: TextStyle(color: AppColors.placeholderGrey)),
                        ),
                      )
                    else
                      ..._codes.map(
                        (c) => Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ListTile(
                            title: Text('*${c.code}'),
                            subtitle: Text(c.municipalityId),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => CodeResolveScreen(code: c.normalizedCode, ancode: c),
                              ),
                            ),
                            trailing: PopupMenuButton<String>(
                              itemBuilder: (ctx) => const [
                                PopupMenuItem(
                                  value: 'copy',
                                  child: ListTile(leading: Icon(Icons.copy), title: Text('Copy link')),
                                ),
                                PopupMenuItem(
                                  value: 'test',
                                  child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Test')),
                                ),
                              ],
                              onSelected: (v) {
                                if (v == 'copy') {
                                  Clipboard.setData(
                                    ClipboardData(text: AppConfig.shortlinkFor(c.normalizedCode)),
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Link copied')),
                                  );
                                } else if (v == 'test') {
                                  final target = c.isLink && c.url != null
                                      ? c.url!
                                      : AppConfig.shortlinkFor(c.normalizedCode);
                                  launchUrl(Uri.parse(target));
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

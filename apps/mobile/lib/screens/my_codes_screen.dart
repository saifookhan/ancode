import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:shared/shared.dart';

import '../services/app_config.dart';
import '../services/ancode_service.dart';
import 'code_resolve_screen.dart';
import '../services/auth_service.dart';
import '../services/plan_mode_service.dart';
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
    final userId = forcedUserId ?? Supabase.instance.client.auth.currentUser?.id ?? auth.profile?.userId;
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
      final rows = await _fetchRowsForUser(userId).timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _codes = rows.map(_rowToAncode).toList();
        _loading = false;
        _lastUserId = userId;
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _codes = [];
        _loading = false;
        _error = 'Timeout loading dashboard codes. Pull to refresh.';
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
    Future<List<Map<String, dynamic>>?> _tryQuery(Future<dynamic> Function() query) async {
      try {
        final res = await query();
        return List<Map<String, dynamic>>.from(res as List);
      } catch (_) {
        return null;
      }
    }

    final byOwnerSimple = await _tryQuery(() => Supabase.instance.client
        .from('codes')
        .select('*')
        .eq('owner_user_id', userId)
        .order('created_at', ascending: false));
    if (byOwnerSimple != null) return byOwnerSimple;

    final byCreatedSimple = await _tryQuery(() => Supabase.instance.client
        .from('codes')
        .select('*')
        .eq('created_by', userId)
        .order('created_at', ascending: false));
    if (byCreatedSimple != null) return byCreatedSimple;

    try {
      final res = await Supabase.instance.client
          .from('codes')
          .select('*')
          .eq('created_by', userId)
          .order('priority_rank', ascending: true)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res);
    } catch (_) {}

    final fromAncodes = await _tryQuery(() => Supabase.instance.client
        .from('ancodes')
        .select('*, municipality:municipalities(*)')
        .eq('owner_user_id', userId)
        .order('created_at', ascending: false));
    if (fromAncodes != null) return fromAncodes;

    return [];
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
        status: AncodeStatus.values.firstWhere(
          (e) => e.name == (r['status']?.toString() ?? 'active'),
          orElse: () => AncodeStatus.active,
        ),
        priorityRank: r['priority_rank'] as int?,
        createdAt: r['created_at'] != null ? DateTime.tryParse(r['created_at'].toString()) : null,
        updatedAt: r['updated_at'] != null ? DateTime.tryParse(r['updated_at'].toString()) : null,
        expiresAt: r['expires_at'] != null ? DateTime.tryParse(r['expires_at'].toString()) : null,
      );
    }
    return Ancode.fromJson({
      ...r,
      'municipality': r['municipality'] is Map ? r['municipality'] : null,
    });
  }

  Future<void> _persistPriorityOrder() async {
    for (var i = 0; i < _codes.length; i++) {
      final code = _codes[i];
      try {
        await Supabase.instance.client.from('codes').update({'priority_rank': i + 1}).eq('id', code.id);
      } catch (_) {}
    }
  }

  Future<void> _removeExclusive(Ancode code) async {
    try {
      await Supabase.instance.client
          .from('codes')
          .update({
            'is_exclusive_italy': false,
            'status': 'active',
            'grace_until': null,
          })
          .eq('id', code.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Esclusivita rimossa: il codice resta attivo sul Comune assegnato')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore rimozione esclusivita: $e')),
      );
    }
  }

  Future<void> _changeMunicipality(Ancode code, String currentPlan) async {
    if (currentPlan == PlanModeService.free) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nel piano FREE i codici non sono modificabili')),
      );
      return;
    }

    String query = '';
    List<Municipality> results = [];
    Municipality? selected;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> onSearch(String q) async {
              query = q;
              if (q.trim().length < 2) {
                setStateDialog(() => results = []);
                return;
              }
              final list = await AncodeService.searchMunicipalities(q.trim());
              if (!mounted) return;
              setStateDialog(() => results = list);
            }

            return AlertDialog(
              title: const Text('Cambia Comune'),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      onChanged: onSearch,
                      decoration: const InputDecoration(
                        hintText: 'Cerca Comune',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (query.trim().length < 2)
                      const Text('Digita almeno 2 caratteri')
                    else if (results.isEmpty)
                      const Text('Nessun comune trovato')
                    else
                      SizedBox(
                        height: 180,
                        child: ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (_, i) {
                            final m = results[i];
                            final isSelected = selected?.istatCode == m.istatCode;
                            return ListTile(
                              dense: true,
                              title: Text(m.name),
                              subtitle: m.province == null ? null : Text(m.province!),
                              trailing: isSelected ? const Icon(Icons.check_circle) : null,
                              onTap: () => setStateDialog(() => selected = m),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Annulla'),
                ),
                FilledButton(
                  onPressed: selected == null ? null : () => Navigator.of(ctx).pop(true),
                  child: const Text('Salva'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true || selected == null) return;
    try {
      await AncodeService.updateCodeMunicipality(
        codeId: code.id,
        municipalityId: selected!.istatCode,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comune aggiornato: ${selected!.name}')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final currentUser = Supabase.instance.client.auth.currentUser;
    final currentPlan = PlanModeService.currentPlan(currentUser);
    final subscriptionEnd = PlanModeService.subscriptionEnd(currentUser);
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
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _codes.length,
                        onReorder: (oldIndex, newIndex) async {
                          setState(() {
                            if (newIndex > oldIndex) newIndex -= 1;
                            final item = _codes.removeAt(oldIndex);
                            _codes.insert(newIndex, item);
                          });
                          await _persistPriorityOrder();
                        },
                        itemBuilder: (context, index) {
                          final c = _codes[index];
                          return Card(
                            key: ValueKey(c.id),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const Icon(Icons.drag_indicator),
                              title: Text('*${c.code}'),
                              subtitle: Text(
                                '${c.municipalityId}\n${PlanModeService.expirationLabel(code: c, plan: currentPlan, subscriptionEndDate: subscriptionEnd)}',
                              ),
                              isThreeLine: true,
                              onTap: c.status == AncodeStatus.grace
                                  ? () => ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Codice in grace period: non cliccabile'),
                                        ),
                                      )
                                  : () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => CodeResolveScreen(code: c.normalizedCode, ancode: c),
                                        ),
                                      ),
                              trailing: PopupMenuButton<String>(
                                itemBuilder: (ctx) => [
                                  const PopupMenuItem(
                                    value: 'copy',
                                    child: ListTile(leading: Icon(Icons.copy), title: Text('Copy link')),
                                  ),
                                  const PopupMenuItem(
                                    value: 'test',
                                    child: ListTile(leading: Icon(Icons.open_in_new), title: Text('Test')),
                                  ),
                                  if (c.isExclusiveItaly)
                                    const PopupMenuItem(
                                      value: 'remove_exclusive',
                                      child: ListTile(leading: Icon(Icons.link_off), title: Text('Remove exclusivity')),
                                    ),
                                  const PopupMenuItem(
                                    value: 'change_municipality',
                                    child: ListTile(leading: Icon(Icons.location_city), title: Text('Change municipality')),
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
                                    final target = c.isLink && c.url != null ? c.url! : AppConfig.shortlinkFor(c.normalizedCode);
                                    launchUrl(Uri.parse(target));
                                  } else if (v == 'remove_exclusive') {
                                    _removeExclusive(c);
                                  } else if (v == 'change_municipality') {
                                    _changeMunicipality(c, currentPlan);
                                  }
                                },
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}

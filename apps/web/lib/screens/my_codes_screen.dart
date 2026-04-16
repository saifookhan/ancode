import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import '../services/app_config.dart';
import '../services/ancode_service.dart';
import '../services/auth_service.dart';
import '../services/plan_mode_service.dart';

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
        await Supabase.instance.client
            .from('codes')
            .update({'priority_rank': i + 1})
            .eq('id', code.id);
      } catch (_) {
        // Backward compatible if priority column not available.
      }
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
              final list = await AncodeService.searchRegionCities(q.trim());
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

  Future<void> _editCodeDetails(Ancode code, String currentPlan) async {
    if (currentPlan == PlanModeService.free) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nel piano FREE i codici non sono modificabili')),
      );
      return;
    }

    final codeController = TextEditingController(text: code.code);
    final contentController = TextEditingController(text: code.isLink ? (code.url ?? '') : (code.noteText ?? ''));
    final citySearchController = TextEditingController(text: code.municipalityId);
    var selectedType = code.type;
    Municipality? selectedCity = Municipality(istatCode: code.municipalityId, name: code.municipalityId);
    List<Municipality> results = [];
    bool saving = false;
    String? dialogError;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            Future<void> onSearch(String q) async {
              final list = q.trim().length < 2
                  ? await AncodeService.listRegionCities()
                  : await AncodeService.searchRegionCities(q.trim());
              if (!mounted) return;
              setStateDialog(() => results = list);
            }

            return AlertDialog(
              backgroundColor: AppColors.biancoOttico,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text(
                'Edit code details',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Code name',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: codeController,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Enter code name',
                          hintStyle: const TextStyle(color: Color(0xFF7C8190)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFD7D9E0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFD7D9E0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.azzurroCiano, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 18),
                      SegmentedButton<AncodeType>(
                        style: SegmentedButton.styleFrom(
                          foregroundColor: Colors.black,
                          selectedForegroundColor: Colors.black,
                          backgroundColor: Colors.white,
                          selectedBackgroundColor: const Color(0xFFE7F5FF),
                          side: const BorderSide(color: AppColors.azzurroCiano),
                          textStyle: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        segments: const [
                          ButtonSegment(value: AncodeType.link, label: Text('Link / URL')),
                          ButtonSegment(value: AncodeType.note, label: Text('Nota / Testo')),
                        ],
                        selected: {selectedType},
                        onSelectionChanged: (values) {
                          setStateDialog(() => selectedType = values.first);
                        },
                      ),
                      const SizedBox(height: 18),
                      Text(
                        selectedType == AncodeType.link ? 'URL' : 'Text / Note',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: contentController,
                        maxLines: selectedType == AncodeType.note ? 4 : 1,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: selectedType == AncodeType.link ? 'https://example.com' : 'Write your note here',
                          hintStyle: const TextStyle(color: Color(0xFF7C8190)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFD7D9E0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFD7D9E0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.azzurroCiano, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        ),
                        style: const TextStyle(color: Colors.black),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Comune',
                        style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: citySearchController,
                        onChanged: onSearch,
                        style: const TextStyle(color: Colors.black),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: Colors.white,
                          hintText: 'Cerca comune',
                          hintStyle: const TextStyle(color: Color(0xFF7C8190)),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFD7D9E0)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: Color(0xFFD7D9E0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: const BorderSide(color: AppColors.azzurroCiano, width: 1.5),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (selectedCity != null)
                        Text(
                          'Selected: ${selectedCity!.name}',
                          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
                        ),
                      const SizedBox(height: 12),
                      Container(
                        height: 170,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFD7D9E0)),
                        ),
                        child: results.isEmpty
                            ? const Center(
                                child: Text(
                                  'Digita almeno 2 caratteri',
                                  style: TextStyle(color: Colors.black87),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                itemCount: results.length,
                                itemBuilder: (_, i) {
                                  final m = results[i];
                                  final isSelected = selectedCity?.istatCode == m.istatCode;
                                  return ListTile(
                                    dense: true,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                                    title: Text(
                                      m.name,
                                      style: const TextStyle(color: Colors.black),
                                    ),
                                    trailing: isSelected ? const Icon(Icons.check_circle) : null,
                                    onTap: () => setStateDialog(() {
                                      selectedCity = m;
                                      citySearchController.text = m.name;
                                    }),
                                  );
                                },
                              ),
                      ),
                      if (dialogError != null) ...[
                        const SizedBox(height: 12),
                        Text(
                          dialogError!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.of(ctx).pop(false),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                  ),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.limeNeobrut,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: saving
                      ? null
                      : () async {
                          setStateDialog(() => saving = true);
                          try {
                            await AncodeService.updateCodeDetails(
                              codeId: code.id,
                              code: codeController.text.trim(),
                              type: selectedType,
                              municipalityId: selectedCity?.istatCode ?? '',
                              url: selectedType == AncodeType.link ? contentController.text.trim() : null,
                              noteText: selectedType == AncodeType.note ? contentController.text.trim() : null,
                            );
                            if (ctx.mounted) Navigator.of(ctx).pop(true);
                          } catch (e) {
                            setStateDialog(() {
                              saving = false;
                              dialogError = e.toString();
                            });
                          }
                        },
                  child: const Text(
                    'Save',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    codeController.dispose();
    contentController.dispose();
    citySearchController.dispose();

    if (confirmed == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code updated')),
      );
      await _load();
    }
  }

  Future<void> _deleteCode(Ancode code) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete code'),
        content: Text('Do you want to delete `*${code.code}`?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await Supabase.instance.client.from('codes').delete().eq('id', code.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Code deleted')),
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
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.bluUniverso),
                        ),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'My created codes',
                            style: TextStyle(
                              color: Color(0xFF1E2230),
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Manage your created ANCODEs',
                      style: TextStyle(
                        color: Color(0xFF6C7280),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
                      ..._codes.map((c) {
                        final canEdit = currentPlan == PlanModeService.pro || currentPlan == PlanModeService.business;
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE5E5E8)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '*${c.code}',
                                      style: const TextStyle(
                                        color: AppColors.bluUniverso,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: () {
                                      Clipboard.setData(
                                        ClipboardData(text: AppConfig.shortlinkFor(c.normalizedCode)),
                                      );
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Link copied')),
                                      );
                                    },
                                    icon: const Icon(Icons.copy_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Comune: ${c.municipalityId}',
                                style: const TextStyle(color: AppColors.bluPolvere, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                PlanModeService.expirationLabel(code: c, plan: currentPlan, subscriptionEndDate: subscriptionEnd),
                                style: const TextStyle(color: AppColors.placeholderGrey),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: _CodeActionButton(
                                      label: 'Edit',
                                      icon: Icons.edit_rounded,
                                      onPressed: canEdit ? () => _editCodeDetails(c, currentPlan) : null,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: _CodeActionButton(
                                      label: 'Delete',
                                      icon: Icons.delete_outline_rounded,
                                      backgroundColor: const Color(0xFFF16D79),
                                      onPressed: () => _deleteCode(c),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
      ),
    );
  }
}

class _CodeActionButton extends StatelessWidget {
  const _CodeActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.backgroundColor = AppColors.bluUniversoDeep,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null;
    return Opacity(
      opacity: disabled ? 0.55 : 1,
      child: SizedBox(
        height: 48,
        child: FilledButton.icon(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: backgroundColor,
            foregroundColor: AppColors.biancoOttico,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          icon: Icon(icon, size: 18),
          label: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ),
      ),
    );
  }
}

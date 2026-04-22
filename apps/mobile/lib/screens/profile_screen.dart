import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import 'auth/login_screen.dart';

const _dashboardChartMonthLabels = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu'];

/// Month starts January–June of the chart year (matches x‑axis labels Gen…Giu).
List<DateTime> _januaryThroughJuneStarts([DateTime? reference]) {
  final y = (reference ?? DateTime.now()).year;
  return List.generate(6, (i) => DateTime(y, i + 1, 1));
}

DateTime? _parseSearchHistoryTimestamp(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onAppHeaderProfileTap});

  final VoidCallback? onAppHeaderProfileTap;

  @override
  ProfileScreenState createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  List<_DashboardCodeItem> _activeCodes = const [];
  List<int> _monthlyScanCounts = List<int>.filled(6, 0);
  bool _loadingStats = false;
  String? _lastLoadedUserId;

  Future<List<Map<String, dynamic>>> _fetchCodesRowsForUser(String userId) async {
    Future<List<Map<String, dynamic>>?> tryQuery(Future<dynamic> Function() query) async {
      try {
        final res = await query();
        return List<Map<String, dynamic>>.from(res as List);
      } catch (_) {
        return null;
      }
    }

    final byOwner = await tryQuery(() => Supabase.instance.client
        .from('codes')
        .select('*')
        .eq('owner_user_id', userId)
        .order('created_at', ascending: false));
    if (byOwner != null) return byOwner;

    final byCreated = await tryQuery(() => Supabase.instance.client
        .from('codes')
        .select('*')
        .eq('created_by', userId)
        .order('created_at', ascending: false));
    if (byCreated != null) return byCreated;

    try {
      final res = await Supabase.instance.client
          .from('codes')
          .select('*')
          .eq('created_by', userId)
          .order('priority_rank', ascending: true)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(res as List);
    } catch (_) {}

    final fromAncodes = await tryQuery(() => Supabase.instance.client
        .from('ancodes')
        .select('*, municipality:municipalities(*)')
        .eq('owner_user_id', userId)
        .order('created_at', ascending: false));
    if (fromAncodes != null) return fromAncodes;

    return [];
  }

  String _normalizedCodeKey(Map<String, dynamic> row) {
    final raw = row['normalized_code'] ?? row['title'] ?? '';
    return normalizeCodeInput(raw.toString());
  }

  Future<({Map<String, int> byCode, List<int> byMonthSlot})> _searchHistoryAggregatesForCodes(
    Iterable<String> normalizedCodes,
    List<DateTime> monthSlotStarts,
  ) async {
    final keys = normalizedCodes.where((k) => k.isNotEmpty).toSet().toList();
    final counts = <String, int>{};
    final byMonth = List<int>.filled(monthSlotStarts.length, 0);
    if (keys.isEmpty) {
      return (byCode: counts, byMonthSlot: byMonth);
    }
    const chunkSize = 80;
    for (var i = 0; i < keys.length; i += chunkSize) {
      final end = (i + chunkSize > keys.length) ? keys.length : i + chunkSize;
      final chunk = keys.sublist(i, end);
      try {
        final res = await Supabase.instance.client
            .from('search_history')
            .select('code, searched_at')
            .inFilter('code', chunk);
        for (final r in res as List) {
          final k = normalizeCodeInput((r['code'] ?? '').toString());
          if (k.isEmpty) continue;
          counts[k] = (counts[k] ?? 0) + 1;
          final at = _parseSearchHistoryTimestamp(r['searched_at']);
          if (at == null) continue;
          final local = at.toLocal();
          final bucket = DateTime(local.year, local.month, 1);
          for (var j = 0; j < monthSlotStarts.length; j++) {
            final slot = monthSlotStarts[j];
            if (slot.year == bucket.year && slot.month == bucket.month) {
              byMonth[j]++;
              break;
            }
          }
        }
      } catch (_) {}
    }
    return (byCode: counts, byMonthSlot: byMonth);
  }

  Future<void> _loadDashboardStats() async {
    final auth = context.read<AuthService>();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? auth.profile?.userId;
    if (userId == null || userId.isEmpty || userId == _lastLoadedUserId) {
      return;
    }
    setState(() => _loadingStats = true);
    try {
      final userCodes = await _fetchCodesRowsForUser(userId);
      if (!mounted) return;

      bool rowIsActive(Map<String, dynamic> r) =>
          (r['status']?.toString().toLowerCase() ?? '') == 'active';

      final activeList = userCodes.where(rowIsActive).toList();
      final codeKeys = userCodes.map(_normalizedCodeKey).where((k) => k.isNotEmpty);
      final monthSlots = _januaryThroughJuneStarts();
      final historyAgg = await _searchHistoryAggregatesForCodes(codeKeys, monthSlots);
      final scanCounts = historyAgg.byCode;
      final activeItems = activeList
          .map((r) => _DashboardCodeItem.fromRow(r, searchHistoryScans: scanCounts[_normalizedCodeKey(r)] ?? 0))
          .toList();
      activeItems.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _activeCodes = activeItems;
        _monthlyScanCounts = historyAgg.byMonthSlot;
        _lastLoadedUserId = userId;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore lettura Supabase codes: $e')),
      );
    } finally {
      if (mounted) setState(() => _loadingStats = false);
    }
  }

  Future<void> reloadDashboardStats() async {
    final auth = context.read<AuthService>();
    final userId = Supabase.instance.client.auth.currentUser?.id ?? auth.profile?.userId;
    if (userId == null || userId.isEmpty || !mounted) return;
    setState(() => _lastLoadedUserId = null);
    await _loadDashboardStats();
  }

  Future<void> _refreshDashboard() => reloadDashboardStats();

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, _, __) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return Scaffold(
          backgroundColor: AppColors.biancoOttico,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LogoProfileAppBar(
                  onProfileTap: widget.onAppHeaderProfileTap,
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshDashboard,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Dashboard',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 34 / 2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _CodesSection(
                            title: 'Codici Attivi',
                            items: _activeCodes,
                            emptyText: 'Nessun codice attivo',
                            inactive: false,
                            viewportMaxRows: 4,
                          ),
                          const SizedBox(height: 14),
                          _ScansTrendCard(values: _monthlyScanCounts, monthLabels: _dashboardChartMonthLabels),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ScansTrendCard extends StatefulWidget {
  const _ScansTrendCard({
    required this.values,
    required this.monthLabels,
  });

  final List<int> values;
  final List<String> monthLabels;

  @override
  State<_ScansTrendCard> createState() => _ScansTrendCardState();
}

class _ScansTrendCardState extends State<_ScansTrendCard> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final months = widget.monthLabels.length == values.length
        ? widget.monthLabels
        : List<String>.generate(
            values.length,
            (i) => i < _dashboardChartMonthLabels.length ? _dashboardChartMonthLabels[i] : '$i',
          );
    final maxVal = values.fold<int>(1, (m, v) => v > m ? v : m);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: AppColors.limeCreateHard,
            blurRadius: 0,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          color: AppColors.biancoOttico,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.bluUniversoDeep, width: 1.7),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Andamento Scansioni',
              style: TextStyle(
                color: AppColors.bluUniversoDeep,
                fontSize: 30 / 2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 190,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final activeIndex = _activeIndex;
                  const tooltipWidth = 104.0;
                  final slotWidth = constraints.maxWidth / months.length;
                  double tooltipLeft = 0;
                  if (activeIndex != null) {
                    tooltipLeft = (slotWidth * activeIndex) + ((slotWidth - tooltipWidth) / 2);
                    tooltipLeft = tooltipLeft.clamp(0, constraints.maxWidth - tooltipWidth);
                  }

                  return Stack(
                    children: [
                      if (activeIndex != null)
                        Positioned(
                          left: (slotWidth * activeIndex) + ((slotWidth - 36) / 2),
                          top: 14,
                          bottom: 28,
                          child: Container(
                            width: 36,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: List.generate(months.length, (i) {
                          final value = i < values.length ? values[i] : 0;
                          final barHeight = 18 + (value / maxVal) * 122;
                          final isActive = _activeIndex == i;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 5),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  MouseRegion(
                                    onEnter: (_) => setState(() => _activeIndex = i),
                                    onExit: (_) => setState(() {
                                      if (_activeIndex == i) _activeIndex = null;
                                    }),
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        setState(() => _activeIndex = _activeIndex == i ? null : i);
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 150),
                                        curve: Curves.easeOut,
                                        height: barHeight,
                                        decoration: BoxDecoration(
                                          color: AppColors.limeCreateHard,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(
                                            color: AppColors.bluUniversoDeep,
                                            width: isActive ? 2 : 1.2,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    months[i],
                                    style: const TextStyle(
                                      color: Color(0xFF566176),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      ),
                      if (activeIndex != null)
                        Positioned(
                          left: tooltipLeft,
                          top: 50,
                          child: _ChartHoverCallout(
                            month: months[activeIndex],
                            value: values[activeIndex],
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartHoverCallout extends StatelessWidget {
  const _ChartHoverCallout({
    required this.month,
    required this.value,
  });

  final String month;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.biancoOttico,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.bluUniversoDeep, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            month,
            style: const TextStyle(
              color: AppColors.bluUniversoDeep,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'scansioni: $value',
            style: const TextStyle(
              color: AppColors.limeCreateHard,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CodesSection extends StatelessWidget {
  const _CodesSection({
    required this.title,
    required this.items,
    required this.emptyText,
    required this.inactive,
    this.viewportMaxRows,
  });

  /// When set, list is this many rows tall and scrolls inside (e.g. Dashboard “Codici Attivi”).
  final int? viewportMaxRows;

  final String title;
  final List<_DashboardCodeItem> items;
  final String emptyText;
  final bool inactive;

  /// Card + gap between rows — tuned to [_CodeRowCard] + list separator height.
  static const double _rowSlotHeight = 68;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.bluUniversoDeep,
            fontSize: 31 / 2,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: inactive ? const Color(0xFFF2F3F5) : AppColors.biancoOttico,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF9CA3AF), width: 1),
            ),
            child: Text(
              emptyText,
              style: const TextStyle(
                color: Color(0xFF6B7280),
                fontSize: 13,
              ),
            ),
          )
        else if (viewportMaxRows != null && viewportMaxRows! > 0)
          SizedBox(
            height: (items.length < viewportMaxRows! ? items.length : viewportMaxRows!) * _rowSlotHeight,
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: items.length,
              physics: const AlwaysScrollableScrollPhysics(),
              separatorBuilder: (_, __) => const SizedBox(height: 5),
              itemBuilder: (context, i) => _CodeRowCard(item: items[i], inactive: inactive),
            ),
          )
        else
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: _CodeRowCard(item: item, inactive: inactive),
              )),
      ],
    );
  }
}

class _CodeRowCard extends StatelessWidget {
  const _CodeRowCard({
    required this.item,
    required this.inactive,
  });

  final _DashboardCodeItem item;
  final bool inactive;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: inactive
            ? const []
            : const [
                BoxShadow(
                  color: AppColors.limeCreateHard,
                  blurRadius: 0,
                  offset: Offset(0, 6),
                ),
              ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 7),
        decoration: BoxDecoration(
          color: inactive ? const Color(0xFFF3F4F6) : AppColors.biancoOttico,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: inactive ? const Color(0xFF9CA3AF) : AppColors.bluUniversoDeep,
            width: 1.1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: inactive ? const Color(0xFF6B7280) : AppColors.bluUniversoDeep,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    inactive ? 'Scaduto: ${item.dateLabel}' : item.dateLabel,
                    style: TextStyle(
                      color: inactive ? const Color(0xFF9CA3AF) : const Color(0xFF64748B),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  item.scans.toString(),
                  style: TextStyle(
                    color: inactive ? const Color(0xFF6B7280) : AppColors.bluUniversoDeep,
                    fontSize: 30 / 2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'scansioni',
                  style: TextStyle(
                    color: inactive ? const Color(0xFF9CA3AF) : const Color(0xFF475569),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardCodeItem {
  const _DashboardCodeItem({
    required this.title,
    required this.date,
    required this.scans,
  });

  final String title;
  final DateTime date;
  final int scans;

  String get dateLabel {
    const months = ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu', 'Lug', 'Ago', 'Set', 'Ott', 'Nov', 'Dic'];
    final month = months[date.month - 1];
    return '${date.day} $month ${date.year}';
  }

  static _DashboardCodeItem fromRow(
    Map<String, dynamic> row, {
    required int searchHistoryScans,
  }) {
    final rawDate = row['created_at'] ?? row['updated_at'] ?? row['expires_at'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final scans = searchHistoryScans;
    final title = (row['title'] ?? row['code'] ?? row['id'] ?? 'Codice').toString();
    return _DashboardCodeItem(
      title: title,
      date: parsedDate ?? DateTime.now(),
      scans: scans,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import 'auth/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  int _activeCodesCount = 0;
  int _deactivatedCodesCount = 0;
  int _totalScansCount = 0;
  List<_DashboardCodeItem> _activeCodes = const [];
  List<_DashboardCodeItem> _deactivatedCodes = const [];
  bool _loadingStats = false;
  String? _lastLoadedUserId;

  Future<void> _loadDashboardStats() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty || userId == _lastLoadedUserId) {
      return;
    }
    setState(() => _loadingStats = true);
    try {
      final rows = await Supabase.instance.client.from('codes').select('*');
      final activeRows = await Supabase.instance.client.from('codes').select('*').eq('status', 'active');
      final inactiveRows = await Supabase.instance.client.from('codes').select('*').eq('status', 'inactive');
      final usageRows = await Supabase.instance.client.from('code_usages').select('*');
      if (!mounted) return;
      final list = (rows as List).cast<Map<String, dynamic>>();
      final activeList = (activeRows as List).cast<Map<String, dynamic>>();
      final inactiveList = (inactiveRows as List).cast<Map<String, dynamic>>();
      final usagesList = (usageRows as List);
      final active = activeList.length;
      final deactivated = inactiveList.length;
      final scans = usagesList.length;
      final activeItems = activeList.map(_DashboardCodeItem.fromRow).toList();
      final deactivatedItems = inactiveList.map(_DashboardCodeItem.fromRow).toList();
      activeItems.sort((a, b) => b.date.compareTo(a.date));
      deactivatedItems.sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _activeCodesCount = active;
        _deactivatedCodesCount = deactivated;
        _totalScansCount = scans;
        _activeCodes = activeItems;
        _deactivatedCodes = deactivatedItems;
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

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, _, __) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        final user = session.user;
        final totalCodes = _activeCodesCount + _deactivatedCodesCount;
        final trend = totalCodes == 0 ? '+0%' : '+${((_activeCodesCount / totalCodes) * 100).round()}%';
        final scanValue = _totalScansCount.toString();
        final monthlyTrend = _buildMonthlyScanTrend(_totalScansCount);

        if (_lastLoadedUserId != user.id && !_loadingStats) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadDashboardStats());
        }

        return Scaffold(
          backgroundColor: AppColors.biancoOttico,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
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
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _DashboardMetricCard(
                        icon: Icons.check_circle_outline_rounded,
                        label: 'Codici attivi',
                        value: '$_activeCodesCount',
                      ),
                      _DashboardMetricCard(
                        icon: Icons.cancel_outlined,
                        label: 'Codici disattivati',
                        value: '$_deactivatedCodesCount',
                      ),
                      _DashboardMetricCard(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scansioni totali',
                        value: scanValue,
                      ),
                      _DashboardMetricCard(
                        icon: Icons.trending_up_rounded,
                        label: 'Andamento',
                        value: trend,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _ScansTrendCard(values: monthlyTrend),
                  const SizedBox(height: 14),
                  _CodesSection(
                    title: 'Codici Attivi',
                    items: _activeCodes,
                    emptyText: 'Nessun codice attivo',
                    inactive: false,
                  ),
                  const SizedBox(height: 10),
                  _CodesSection(
                    title: 'Codici Disattivati',
                    items: _deactivatedCodes,
                    emptyText: 'Nessun codice disattivato',
                    inactive: true,
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardMetricCard extends StatelessWidget {
  const _DashboardMetricCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: AppColors.limeCreateHard,
            blurRadius: 0,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.biancoOttico,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.bluUniversoDeep, width: 1.4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.limeCreateHard,
                border: Border.all(color: AppColors.bluUniversoDeep, width: 1.2),
              ),
              child: Icon(icon, size: 18, color: AppColors.bluUniversoDeep),
            ),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF566176),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.bluUniversoDeep,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

List<int> _buildMonthlyScanTrend(int totalScans) {
  if (totalScans <= 0) {
    return const [40, 55, 72, 90, 110, 130];
  }
  final base = (totalScans / 6).round();
  final factors = <double>[0.55, 0.75, 0.9, 1.08, 1.22, 1.35];
  return factors.map((f) => (base * f).round()).toList();
}

class _ScansTrendCard extends StatefulWidget {
  const _ScansTrendCard({required this.values});

  final List<int> values;

  @override
  State<_ScansTrendCard> createState() => _ScansTrendCardState();
}

class _ScansTrendCardState extends State<_ScansTrendCard> {
  int? _activeIndex;

  @override
  Widget build(BuildContext context) {
    final months = const ['Gen', 'Feb', 'Mar', 'Apr', 'Mag', 'Giu'];
    final values = widget.values;
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
  });

  final String title;
  final List<_DashboardCodeItem> items;
  final String emptyText;
  final bool inactive;

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
        else
          ...items.take(4).map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 7),
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
        padding: const EdgeInsets.fromLTRB(16, 11, 16, 10),
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

  static _DashboardCodeItem fromRow(Map<String, dynamic> row) {
    final rawDate = row['created_at'] ?? row['updated_at'] ?? row['expires_at'];
    final parsedDate = rawDate is String ? DateTime.tryParse(rawDate) : null;
    final dynamic scanValue = row['scan_count'] ?? row['total_scans'];
    int scans = 0;
    if (scanValue is num) {
      scans = scanValue.toInt();
    } else if (scanValue is String) {
      scans = int.tryParse(scanValue) ?? 0;
    }
    final title = (row['title'] ?? row['code'] ?? row['id'] ?? 'Codice').toString();
    return _DashboardCodeItem(
      title: title,
      date: parsedDate ?? DateTime.now(),
      scans: scans,
    );
  }
}

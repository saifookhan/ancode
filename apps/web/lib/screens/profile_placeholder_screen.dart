import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shared/shared.dart';

import '../services/auth_service.dart';
import 'auth/login_screen.dart';
import 'plan_selection_screen.dart';

class ProfilePlaceholderScreen extends StatefulWidget {
  const ProfilePlaceholderScreen({super.key});

  @override
  State<ProfilePlaceholderScreen> createState() => _ProfilePlaceholderScreenState();
}

class _ProfilePlaceholderScreenState extends State<ProfilePlaceholderScreen> {
  int _activeCodesCount = 0;
  int _totalScansCount = 0;
  bool _loadingCodesCount = false;
  String? _lastLoadedUserId;

  Future<void> _loadCodesCount() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty || userId == _lastLoadedUserId) return;
    setState(() => _loadingCodesCount = true);
    try {
      final rows = await Supabase.instance.client.from('codes').select('*');
      final activeRows = await Supabase.instance.client.from('codes').select('id').eq('status', 'active');
      final usageRows = await Supabase.instance.client.from('code_usages').select('id');

      final usageCount = (usageRows as List).length;
      var scans = usageCount;
      if (scans == 0) {
        for (final row in (rows as List).cast<Map<String, dynamic>>()) {
          final dynamic scanValue = row['scan_count'] ?? row['total_scans'] ?? row['scans'];
          if (scanValue is num) {
            scans += scanValue.toInt();
          } else if (scanValue is String) {
            scans += int.tryParse(scanValue) ?? 0;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _activeCodesCount = (activeRows as List).length;
        _totalScansCount = scans;
        _lastLoadedUserId = userId;
      });
    } finally {
      if (mounted) setState(() => _loadingCodesCount = false);
    }
  }

  int _planCodeLimit(String rawPlan) {
    switch (rawPlan) {
      case 'business':
        return 999;
      case 'pro':
        return 50;
      default:
        return 5;
    }
  }

  double _progressValue(int count, int max) {
    if (max <= 0) return 0;
    final value = count / max;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
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
        final metadata = user.userMetadata ?? <String, dynamic>{};
        final name = metadata['name']?.toString().trim() ?? '';
        final surname = metadata['surname']?.toString().trim() ?? '';
        final fullName = '$name $surname'.trim().isEmpty ? 'Utente ANCODE' : '$name $surname'.trim();
        final email = user.email ?? '';
        final rawPlan = user.userMetadata?['plan']?.toString().toLowerCase() ?? 'free';
        final displayPlan = rawPlan.isEmpty ? 'Free' : '${rawPlan[0].toUpperCase()}${rawPlan.substring(1)}';
        final maxCodes = _planCodeLimit(rawPlan);
        final currentCount = _loadingCodesCount ? 0 : _activeCodesCount;
        final progress = _progressValue(currentCount, maxCodes);

        if (_lastLoadedUserId != user.id && !_loadingCodesCount) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _loadCodesCount());
        }

        return Scaffold(
          backgroundColor: AppColors.biancoOttico,
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                    decoration: BoxDecoration(
                      color: AppColors.biancoOttico,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.bluUniversoDeep, width: 2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.bluUniversoDeep,
                            border: Border.all(color: AppColors.limeCreateHard, width: 2.5),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            fullName.characters.first.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: const TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.bluUniversoDeep,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                email,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF697486),
                                  fontWeight: FontWeight.w500,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: 124,
                                child: WhiteLimePillSurface(
                                  height: 38,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.workspace_premium_outlined,
                                        size: 16,
                                        color: AppColors.bluUniversoDeep,
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'Piano $displayPlan',
                                        style: const TextStyle(
                                          color: AppColors.bluUniversoDeep,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  GridView.count(
                    crossAxisCount: 2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.35,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _DashboardMetricCard(
                        icon: Icons.trending_up_rounded,
                        label: 'Scansioni totali',
                        value: _totalScansCount.toString(),
                      ),
                      _DashboardMetricCard(
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Codici attivi',
                        value: _activeCodesCount.toString(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 16),
                    decoration: BoxDecoration(
                      color: AppColors.biancoOttico,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: AppColors.bluUniversoDeep, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dettagli Piano',
                          style: TextStyle(
                            color: AppColors.bluUniversoDeep,
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Codici creati',
                              style: TextStyle(
                                fontSize: 15,
                                color: AppColors.bluUniversoDeep,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              maxCodes > 900 ? '$currentCount / Illimitati' : '$currentCount / $maxCodes',
                              style: const TextStyle(
                                fontSize: 15,
                                color: AppColors.bluUniversoDeep,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            minHeight: 12,
                            value: maxCodes > 900 ? 0.3 : progress,
                            backgroundColor: const Color(0xFFE4E9ED),
                            color: AppColors.limeCreateHard,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _PlanFeature(label: maxCodes > 900 ? 'Codici illimitati' : 'Fino a $maxCodes codici attivi'),
                        const _PlanFeature(label: 'Durata legata al piano attivo'),
                        const _PlanFeature(label: 'Statistiche avanzate'),
                        const _PlanFeature(label: 'Layout di stampa personalizzati'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _MenuActionTile(
                    icon: Icons.credit_card_outlined,
                    label: 'Gestione Abbonamento',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => const PlanSelectionScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _MenuActionTile(
                    icon: Icons.settings_outlined,
                    label: 'Impostazioni',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Sezione impostazioni in arrivo.')),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _MenuActionTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Supporto & FAQ',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Supporto e FAQ in arrivo.')),
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  _LogoutActionButton(
                    onTap: () async {
                      await context.read<AuthService>().signOut();
                      if (context.mounted) {
                        await context.read<AuthService>().refreshProfile();
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Versione 1.0.0 - © 2026 ANCODE',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.bluUniversoDeep,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LogoutActionButton extends StatelessWidget {
  const _LogoutActionButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0xFFF05151),
            blurRadius: 0,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: AppColors.biancoOttico,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFF05151), width: 1.2),
            ),
            alignment: Alignment.center,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, size: 18, color: Color(0xFFF05151)),
                SizedBox(width: 8),
                Text(
                  'Esci',
                  style: TextStyle(
                    color: Color(0xFFF05151),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanFeature extends StatelessWidget {
  const _PlanFeature({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.limeCreateHard,
              border: Border.fromBorderSide(BorderSide(color: AppColors.bluUniversoDeep, width: 1)),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.bluUniversoDeep,
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuActionTile extends StatelessWidget {
  const _MenuActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return WhiteLimePillSurface(
      height: 62,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, color: AppColors.bluUniversoDeep, size: 20),
                const SizedBox(width: 14),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.bluUniversoDeep,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF778091), size: 24),
              ],
            ),
          ),
        ),
      ),
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

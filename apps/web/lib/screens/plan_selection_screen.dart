import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared/shared.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import '../services/plan_mode_service.dart';

/// Schermata gestione abbonamento: scelta piano, checkout Stripe, downgrade a Gratuito.
class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  static const _mutedGrey = Color(0xFF697486);
  static const List<String> _planIds = ['Free', 'Pro', 'Business'];

  late String _initialPlan;
  String _selectedPlan = 'Free';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final plan = (user?.userMetadata?['plan']?.toString() ?? 'free').toLowerCase();
    _initialPlan = _normalizePlan(plan);
    _selectedPlan = _initialPlan;
  }

  String _normalizePlan(String raw) {
    switch (raw.toLowerCase()) {
      case 'pro':
        return 'Pro';
      case 'business':
        return 'Business';
      default:
        return 'Free';
    }
  }

  String _planTitle(String plan) {
    switch (plan) {
      case 'Pro':
        return 'Pro';
      case 'Business':
        return 'Business';
      default:
        return 'Gratuito';
    }
  }

  String _planSubtitle(String plan) {
    switch (plan) {
      case 'Pro':
        return 'Fino a 50 codici attivi, statistiche e layout di stampa.';
      case 'Business':
        return 'Codici illimitati e funzioni avanzate per organizzazioni.';
      default:
        return 'Fino a 5 codici attivi per iniziare.';
    }
  }

  IconData _planIcon(String plan) {
    switch (plan) {
      case 'Pro':
        return Icons.bolt_outlined;
      case 'Business':
        return Icons.apartment_outlined;
      default:
        return Icons.rocket_launch_outlined;
    }
  }

  bool get _isNoOpFree => _selectedPlan == 'Free' && _initialPlan == 'Free';

  String get _primaryLabel {
    if (_isNoOpFree) return 'Piano attivo';
    if (_selectedPlan == 'Free') return 'Conferma piano Gratuito';
    return 'Vai al pagamento sicuro';
  }

  String _italianShortDate(DateTime d) {
    const months = [
      'gen', 'feb', 'mar', 'apr', 'mag', 'giu',
      'lug', 'ago', 'set', 'ott', 'nov', 'dic',
    ];
    final l = d.toLocal();
    return '${l.day} ${months[l.month - 1]} ${l.year}';
  }

  Future<void> _applyFreePlan(User user) async {
    const planValue = 'free';
    await Supabase.instance.client.auth.updateUser(
      UserAttributes(
        data: {
          'plan': planValue,
          'subscription_end': null,
        },
      ),
    );
    try {
      await upsertProfileForUserId(Supabase.instance.client, user.id, {'plan': planValue});
    } catch (_) {}
    try {
      await Supabase.instance.client.from('subscriptions').upsert({
        'user_id': user.id,
        'plan': planValue,
        'status': 'canceled',
        'current_period_end': null,
      }, onConflict: 'user_id');
    } catch (_) {}
    await PlanModeService.enforcePlanRules(
      client: Supabase.instance.client,
      userId: user.id,
      plan: planValue,
      subscriptionEndDate: null,
    );
  }

  Future<void> _startStripeCheckout(User user, String planValue) async {
    final response = await Supabase.instance.client.functions.invoke(
      'create-checkout-session',
      body: {
        'plan': planValue,
        'userId': user.id,
        'email': user.email ?? '',
        'successUrl': StripeCheckoutLinks.successUrl(planValue),
        'cancelUrl': StripeCheckoutLinks.cancelUrl,
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Risposta del server non valida.');
    }
    final checkoutUrl = data['url']?.toString();
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception('Indirizzo di pagamento non disponibile.');
    }
    await StripeCheckoutLinks.openCheckoutPage(checkoutUrl);
  }

  Future<void> _savePlan() async {
    if (_isSaving) return;
    if (_isNoOpFree) return;
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Accedi per continuare.')),
        );
        return;
      }
      final planValue = _selectedPlan.toLowerCase();
      if (planValue == 'free') {
        await _applyFreePlan(user);
      } else {
        await _startStripeCheckout(user, planValue);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Completa il pagamento su Stripe per attivare il piano.')),
        );
        return;
      }

      if (!mounted) return;
      await context.read<AuthService>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Piano aggiornato.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      final raw = e.toString();
      final msg = raw.startsWith('Exception: ') ? raw.substring('Exception: '.length) : raw;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg.isNotEmpty ? msg : 'Operazione non riuscita.')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Widget _sectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: AppColors.biancoOttico,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.bluUniversoDeep, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _planTile(String plan) {
    final selected = _selectedPlan == plan;
    final isCurrent = _initialPlan == plan;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSaving ? null : () => setState(() => _selectedPlan = plan),
          borderRadius: BorderRadius.circular(22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: selected ? AppColors.limeCreateHard : AppColors.bluUniversoDeep,
                width: selected ? 2.5 : 1.5,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(_planIcon(plan), color: AppColors.bluUniversoDeep, size: 26),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _planTitle(plan),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: AppColors.bluUniversoDeep,
                            ),
                          ),
                          if (isCurrent) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.verdeCosmicoSoft,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: AppColors.bluUniversoDeep, width: 1),
                              ),
                              child: const Text(
                                'Attuale',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.bluUniversoDeep,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _planSubtitle(plan),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _mutedGrey,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Padding(
                    padding: EdgeInsets.only(left: 6, top: 2),
                    child: Icon(Icons.check_circle, color: AppColors.bluUniversoDeep, size: 22),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final subEnd = PlanModeService.subscriptionEnd(user);
    final renewalEnd = (subEnd != null && subEnd.toUtc().isAfter(DateTime.now().toUtc()))
        ? subEnd
        : null;

    return Scaffold(
      backgroundColor: AppColors.biancoOttico,
      appBar: AppBar(
        backgroundColor: AppColors.biancoOttico,
        foregroundColor: AppColors.bluUniversoDeep,
        elevation: 0,
        title: const Text(
          'Gestione abbonamento',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
          children: [
            _sectionCard(
              children: [
                const Text(
                  'Il tuo piano',
                  style: TextStyle(
                    color: AppColors.bluUniversoDeep,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _planTitle(_initialPlan),
                  style: const TextStyle(
                    color: AppColors.bluUniversoDeep,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                  ),
                ),
                if (renewalEnd != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Abbonamento attivo fino al ${_italianShortDate(renewalEnd)}.',
                    style: const TextStyle(
                      color: _mutedGrey,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ] else if (_initialPlan != 'Free') ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Controlla i dettagli di fatturazione dal portale Stripe al termine del periodo.',
                    style: TextStyle(
                      color: _mutedGrey,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            _sectionCard(
              children: [
                const Text(
                  'Scegli il piano',
                  style: TextStyle(
                    color: AppColors.bluUniversoDeep,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Per Pro e Business verrai reindirizzato al checkout sicuro di Stripe.',
                  style: TextStyle(
                    color: _mutedGrey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                ..._planIds.map(_planTile),
              ],
            ),
            const SizedBox(height: 22),
            LimeRailPillButton(
              label: _primaryLabel,
              height: 56,
              loading: _isSaving,
              onPressed: (_isSaving || _isNoOpFree) ? null : _savePlan,
            ),
            const SizedBox(height: 14),
            const Text(
              'I prezzi e le condizioni possono variare: il pagamento è gestito da Stripe.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _mutedGrey,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

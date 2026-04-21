import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/auth_service.dart';
import '../services/plan_mode_service.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  static const List<String> _plans = ['Free', 'Pro', 'Business'];
  String _selectedPlan = 'Free';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = Supabase.instance.client.auth.currentUser;
    final plan = (user?.userMetadata?['plan']?.toString() ?? 'free').toLowerCase();
    _selectedPlan = _normalizePlan(plan);
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
      await Supabase.instance.client.from('profiles').upsert({'user_id': user.id, 'plan': planValue}, onConflict: 'user_id');
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
    const origin = 'https://ancode.vercel.app';
    final response = await Supabase.instance.client.functions.invoke(
      'create-checkout-session',
      body: {
        'plan': planValue,
        'userId': user.id,
        'email': user.email ?? '',
        'successUrl': '$origin/?checkout=success&plan=$planValue',
        'cancelUrl': '$origin/?checkout=cancel',
      },
    );
    final data = response.data;
    if (data is! Map<String, dynamic>) {
      throw Exception('Invalid checkout response');
    }
    final checkoutUrl = data['url']?.toString();
    if (checkoutUrl == null || checkoutUrl.isEmpty) {
      throw Exception('Invalid checkout URL');
    }
    final uri = Uri.parse(checkoutUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('Cannot open checkout URL');
  }

  Future<void> _savePlan() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login first.')));
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plan updated successfully.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your plan')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Select plan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedPlan,
                style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
                dropdownColor: Colors.white,
                iconEnabledColor: Colors.black87,
                decoration: const InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _plans.map((plan) => DropdownMenuItem<String>(value: plan, child: Text(plan))).toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedPlan = value);
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'Per i piani Pro/Business verrai reindirizzato al checkout Stripe.',
                style: TextStyle(color: Colors.black54),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _savePlan,
                  child: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Save plan'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> _savePlan() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please login first.')),
        );
        return;
      }

      final planValue = _selectedPlan.toLowerCase();
      final now = DateTime.now().toUtc();
      final subscriptionEnd = planValue == 'free'
          ? null
          : now.add(planValue == 'pro' ? const Duration(days: 30) : const Duration(days: 30));
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(
          data: {
            'plan': planValue,
            'subscription_end': subscriptionEnd?.toIso8601String(),
          },
        ),
      );

      try {
        await Supabase.instance.client.from('profiles').upsert(
          {
            'user_id': user.id,
            'plan': planValue,
          },
          onConflict: 'user_id',
        );
      } catch (_) {
        // Optional profile column: ignore when not present.
      }
      try {
        await Supabase.instance.client.from('subscriptions').upsert(
          {
            'user_id': user.id,
            'plan': planValue,
            'status': planValue == 'free' ? 'canceled' : 'active',
            'current_period_end': subscriptionEnd?.toIso8601String(),
          },
          onConflict: 'user_id',
        );
      } catch (_) {
        // Backward-compatible when subscriptions table is absent/mismatched.
      }

      await PlanModeService.enforcePlanRules(
        client: Supabase.instance.client,
        userId: user.id,
        plan: planValue,
        subscriptionEndDate: subscriptionEnd,
      );

      if (!mounted) return;
      await context.read<AuthService>().refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Plan updated successfully.')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
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
              const Text(
                'Select plan',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedPlan,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: _plans
                    .map(
                      (plan) => DropdownMenuItem<String>(
                        value: plan,
                        child: Text(plan),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedPlan = value);
                },
              ),
              const SizedBox(height: 18),
              const Text(
                'This is a temporary page for plan mode selection. Payment flow will be added later.',
                style: TextStyle(color: Colors.black54),
              ),
              const Spacer(),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _isSaving ? null : _savePlan,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
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

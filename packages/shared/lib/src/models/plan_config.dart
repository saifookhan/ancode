import 'package:equatable/equatable.dart';

import 'subscription.dart';

/// Plan limits loaded from DB; configurable without code changes
class PlanConfig extends Equatable {
  const PlanConfig({
    required this.plan,
    required this.maxActiveCodes,
    required this.codeExpiryDays,
    this.maxExclusiveSlots = 0,
    this.minCodeLength = 1,
    this.isEditable = false,
  });

  final PlanType plan;
  final int maxActiveCodes;
  final int codeExpiryDays; // 0 = no per-code expiry (valid until sub end)
  final int maxExclusiveSlots;
  final int minCodeLength;
  final bool isEditable;

  factory PlanConfig.fromJson(Map<String, dynamic> json) {
    return PlanConfig(
      plan: PlanType.values.firstWhere(
        (e) => e.name == json['plan'],
        orElse: () => PlanType.free,
      ),
      maxActiveCodes: json['max_active_codes'] as int? ?? 5,
      codeExpiryDays: json['code_expiry_days'] as int? ?? 30,
      maxExclusiveSlots: json['max_exclusive_slots'] as int? ?? 0,
      minCodeLength: json['min_code_length'] as int? ?? 1,
      isEditable: json['is_editable'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [plan, maxActiveCodes, codeExpiryDays];
}

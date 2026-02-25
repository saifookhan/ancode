import 'package:equatable/equatable.dart';

enum PlanType { free, pro, business }

enum SubscriptionStatus {
  active,
  pastDue,
  canceled,
  trialing,
  incomplete,
  incompleteExpired,
}

class Subscription extends Equatable {
  const Subscription({
    required this.userId,
    required this.plan,
    required this.status,
    this.stripeCustomerId,
    this.stripeSubscriptionId,
    this.currentPeriodEnd,
    this.pastDueSince,
    this.createdAt,
    this.updatedAt,
  });

  final String userId;
  final PlanType plan;
  final SubscriptionStatus status;
  final String? stripeCustomerId;
  final String? stripeSubscriptionId;
  final DateTime? currentPeriodEnd;
  final DateTime? pastDueSince;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isActive =>
      status == SubscriptionStatus.active ||
      status == SubscriptionStatus.trialing;
  bool get isPastDue => status == SubscriptionStatus.pastDue;

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription(
      userId: json['user_id'] as String,
      plan: PlanType.values.firstWhere(
        (e) => e.name == json['plan'],
        orElse: () => PlanType.free,
      ),
      status: SubscriptionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SubscriptionStatus.canceled,
      ),
      stripeCustomerId: json['stripe_customer_id'] as String?,
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      currentPeriodEnd: json['current_period_end'] != null
          ? DateTime.parse(json['current_period_end'] as String)
          : null,
      pastDueSince: json['past_due_since'] != null
          ? DateTime.parse(json['past_due_since'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [userId, plan, status];
}

# Subscriptions (Stripe)

Plans are enforced server-side. State synced via Stripe webhooks to `subscriptions` table.

## Plans (plan_config)
- **FREE**: max_active_codes=5, code_expiry_days=30
- **PRO**: max_exclusive_slots=1, is_editable=true
- **BUSINESS**: N exclusive slots, scheduling (activation window)

## Webhook Handler
`supabase/functions/stripe-webhook` handles:
- `customer.subscription.created/updated`: Upsert subscription
- `customer.subscription.deleted`: Set canceled
- `invoice.payment_failed`: Set past_due

## Grace Period
Exclusive codes enter 30-day GRACE when subscription expires; hidden from search.

## Failed Payments
7-day tolerance for PAST_DUE; after that, apply expiration rules.

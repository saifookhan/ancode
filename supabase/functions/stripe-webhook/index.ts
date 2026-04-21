import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import Stripe from 'https://esm.sh/stripe@14.14.0'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2023-10-16',
})
const webhookSecret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? ''
const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''

type SupabaseAdmin = ReturnType<typeof createClient>

async function resolveUserIdFromStripeCustomer(
  supabase: SupabaseAdmin,
  customerId: string,
): Promise<string | null> {
  const { data } = await supabase
    .from('subscriptions')
    .select('user_id')
    .eq('stripe_customer_id', customerId)
    .maybeSingle()
  return data?.user_id ?? null
}

async function recordPayment(
  supabase: SupabaseAdmin,
  row: {
    user_id: string
    stripe_event_id: string
    stripe_checkout_session_id?: string | null
    stripe_invoice_id?: string | null
    stripe_payment_intent_id?: string | null
    stripe_subscription_id?: string | null
    stripe_customer_id?: string | null
    amount_cents: number | null
    currency: string
    plan: string | null
    status: string
    event_type: string
    metadata?: Record<string, unknown>
  },
) {
  const { error } = await supabase.from('payments').insert({
    user_id: row.user_id,
    stripe_event_id: row.stripe_event_id,
    stripe_checkout_session_id: row.stripe_checkout_session_id ?? null,
    stripe_invoice_id: row.stripe_invoice_id ?? null,
    stripe_payment_intent_id: row.stripe_payment_intent_id ?? null,
    stripe_subscription_id: row.stripe_subscription_id ?? null,
    stripe_customer_id: row.stripe_customer_id ?? null,
    amount_cents: row.amount_cents,
    currency: row.currency,
    plan: row.plan,
    status: row.status,
    event_type: row.event_type,
    metadata: row.metadata ?? {},
    updated_at: new Date().toISOString(),
  })
  if (error) {
    if (String(error.message).toLowerCase().includes('duplicate') || error.code === '23505') {
      return
    }
    console.error('payments insert error:', error)
  }
}

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 })
  }
  const signature = req.headers.get('stripe-signature')
  if (!signature || !webhookSecret) {
    return new Response('Missing signature', { status: 400 })
  }
  const body = await req.text()
  let event: Stripe.Event
  try {
    event = stripe.webhooks.constructEvent(body, signature, webhookSecret)
  } catch (err) {
    console.error('Webhook signature verification failed:', err)
    return new Response('Invalid signature', { status: 400 })
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey)

  switch (event.type) {
    case 'checkout.session.completed': {
      const session = event.data.object as Stripe.Checkout.Session
      const userId = session.client_reference_id
      if (!userId) break
      const customerId =
        typeof session.customer === 'string'
          ? session.customer
          : session.customer?.id ?? null
      const subscriptionId =
        typeof session.subscription === 'string'
          ? session.subscription
          : (session.subscription as Stripe.Subscription | null)?.id ?? null
      let plan = (session.metadata?.plan ?? '').toString().toLowerCase()
      if (!plan && subscriptionId) {
        try {
          const sub = await stripe.subscriptions.retrieve(subscriptionId)
          plan =
            (sub.metadata?.plan ?? sub.items.data[0]?.price?.metadata?.plan ?? 'pro')
              .toString()
              .toLowerCase()
        } catch (_) {
          plan = 'pro'
        }
      }
      if (!['pro', 'business'].includes(plan)) plan = 'pro'
      await recordPayment(supabase, {
        user_id: userId,
        stripe_event_id: event.id,
        stripe_checkout_session_id: session.id,
        stripe_subscription_id: subscriptionId,
        stripe_customer_id: customerId,
        stripe_payment_intent_id:
          typeof session.payment_intent === 'string'
            ? session.payment_intent
            : session.payment_intent?.id ?? null,
        amount_cents: session.amount_total ?? null,
        currency: (session.currency ?? 'usd').toLowerCase(),
        plan,
        status: session.payment_status === 'paid' ? 'succeeded' : session.payment_status ?? 'completed',
        event_type: event.type,
        metadata: {
          mode: session.mode,
          payment_status: session.payment_status,
        },
      })
      break
    }
    case 'invoice.payment_succeeded': {
      const invoice = event.data.object as Stripe.Invoice
      const customerId = typeof invoice.customer === 'string'
        ? invoice.customer
        : invoice.customer?.id ?? null
      if (!customerId) break
      let userId = await resolveUserIdFromStripeCustomer(supabase, customerId)
      if (!userId && invoice.customer_email) {
        const { data: users } = await supabase.auth.admin.listUsers()
        const u = users?.users?.find((x) => x.email === invoice.customer_email)
        userId = u?.id ?? null
      }
      if (!userId) break
      const subscriptionId =
        typeof invoice.subscription === 'string' ? invoice.subscription : invoice.subscription?.id ?? null
      const pi =
        typeof invoice.payment_intent === 'string'
          ? invoice.payment_intent
          : invoice.payment_intent?.id ?? null
      const planFromLines = invoice.lines?.data?.[0]?.metadata?.plan
      const plan = (planFromLines ?? 'pro').toString().toLowerCase()
      await recordPayment(supabase, {
        user_id: userId,
        stripe_event_id: event.id,
        stripe_invoice_id: invoice.id,
        stripe_payment_intent_id: pi,
        stripe_subscription_id: subscriptionId,
        stripe_customer_id: customerId,
        amount_cents: invoice.amount_paid ?? null,
        currency: (invoice.currency ?? 'usd').toLowerCase(),
        plan: ['pro', 'business'].includes(plan) ? plan : 'pro',
        status: 'succeeded',
        event_type: event.type,
        metadata: {
          billing_reason: invoice.billing_reason,
          invoice_number: invoice.number,
        },
      })
      break
    }
    case 'invoice.payment_failed': {
      const invoice = event.data.object as Stripe.Invoice
      const customerId = typeof invoice.customer === 'string'
        ? invoice.customer
        : invoice.customer?.id ?? null
      if (!customerId) break
      let userId = await resolveUserIdFromStripeCustomer(supabase, customerId)
      if (!userId && invoice.customer_email) {
        const { data: users } = await supabase.auth.admin.listUsers()
        const u = users?.users?.find((x) => x.email === invoice.customer_email)
        userId = u?.id ?? null
      }
      if (!userId) break
      const subscriptionId =
        typeof invoice.subscription === 'string' ? invoice.subscription : invoice.subscription?.id ?? null
      const pi =
        typeof invoice.payment_intent === 'string'
          ? invoice.payment_intent
          : invoice.payment_intent?.id ?? null
      await recordPayment(supabase, {
        user_id: userId,
        stripe_event_id: event.id,
        stripe_invoice_id: invoice.id,
        stripe_payment_intent_id: pi,
        stripe_subscription_id: subscriptionId,
        stripe_customer_id: customerId,
        amount_cents: invoice.amount_due ?? null,
        currency: (invoice.currency ?? 'usd').toLowerCase(),
        plan: null,
        status: 'failed',
        event_type: event.type,
        metadata: {
          billing_reason: invoice.billing_reason,
          attempt_count: invoice.attempt_count,
        },
      })
      const subId = invoice.subscription as string
      if (!subId) break
      await supabase
        .from('subscriptions')
        .update({
          status: 'past_due',
          past_due_since: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq('stripe_subscription_id', subId)
      break
    }
    case 'customer.subscription.created':
    case 'customer.subscription.updated': {
      const sub = event.data.object as Stripe.Subscription
      const customerId = sub.customer as string
      const customer = await stripe.customers.retrieve(customerId)
      const email = (customer as Stripe.Customer).email
      if (!email) break
      const { data: users } = await supabase.auth.admin.listUsers()
      const user = users?.users?.find((u) => u.email === email)
      if (!user) break
      const plan =
        sub.items.data[0]?.price?.metadata?.plan ??
        sub.metadata?.plan ??
        'pro'
      const status = sub.status === 'active' || sub.status === 'trialing'
        ? 'active'
        : sub.status === 'past_due'
        ? 'past_due'
        : 'canceled'
      await supabase.from('subscriptions').upsert({
        user_id: user.id,
        stripe_customer_id: customerId,
        stripe_subscription_id: sub.id,
        plan,
        status,
        current_period_end: sub.current_period_end
          ? new Date(sub.current_period_end * 1000).toISOString()
          : null,
        past_due_since:
          status === 'past_due'
            ? new Date().toISOString()
            : null,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' })
      try {
        await supabase.auth.admin.updateUserById(user.id, {
          user_metadata: {
            ...(user.user_metadata ?? {}),
            plan,
            subscription_end: sub.current_period_end
              ? new Date(sub.current_period_end * 1000).toISOString()
              : null,
          },
        })
      } catch (_) {}
      break
    }
    case 'customer.subscription.deleted': {
      const sub = event.data.object as Stripe.Subscription
      await supabase
        .from('subscriptions')
        .update({
          status: 'canceled',
          stripe_subscription_id: null,
          updated_at: new Date().toISOString(),
        })
        .eq('stripe_subscription_id', sub.id)
      break
    }
    default:
      console.log('Unhandled event:', event.type)
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  })
})

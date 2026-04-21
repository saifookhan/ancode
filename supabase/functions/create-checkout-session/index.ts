import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import Stripe from 'https://esm.sh/stripe@14.14.0'

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY') ?? '', {
  apiVersion: '2023-10-16',
})

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }

  try {
    const body = await req.json()
    const plan = (body?.plan ?? '').toString().toLowerCase()
    const userId = (body?.userId ?? '').toString()
    const email = (body?.email ?? '').toString()
    const successUrl = (body?.successUrl ?? '').toString()
    const cancelUrl = (body?.cancelUrl ?? '').toString()

    if (!['pro', 'business'].includes(plan)) {
      return new Response(JSON.stringify({ error: 'Invalid plan' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }
    if (!userId || !email || !successUrl || !cancelUrl) {
      return new Response(JSON.stringify({ error: 'Missing required fields' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      })
    }

    const pricePro = Deno.env.get('STRIPE_PRICE_PRO') ?? ''
    const priceBusiness = Deno.env.get('STRIPE_PRICE_BUSINESS') ?? ''
    const params: Stripe.Checkout.SessionCreateParams = {
      mode: 'subscription',
      success_url: successUrl,
      cancel_url: cancelUrl,
      customer_email: email,
      client_reference_id: userId,
      line_items: [
        {
          quantity: 1,
        },
      ],
      subscription_data: {
        metadata: {
          plan,
          user_id: userId,
        },
      },
    }

    const configuredPrice = plan === 'business' ? priceBusiness : pricePro
    if (configuredPrice) {
      params.line_items![0].price = configuredPrice
    } else {
      params.line_items![0].price_data = {
        currency: 'usd',
        unit_amount: plan === 'business' ? 3000 : 2000, // temporary fallback
        recurring: { interval: 'month' },
        product_data: {
          name: `ANCODE ${plan === 'business' ? 'Business' : 'Pro'} Plan`,
          metadata: { plan },
        },
      }
    }

    const session = await stripe.checkout.sessions.create(params)
    return new Response(JSON.stringify({ url: session.url }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e?.message ?? String(e) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})

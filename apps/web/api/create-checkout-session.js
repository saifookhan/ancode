module.exports = async (req, res) => {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const secretKey = process.env.STRIPE_SECRET_KEY || '';
  const pricePro = process.env.STRIPE_PRICE_PRO || '';
  const priceBusiness = process.env.STRIPE_PRICE_BUSINESS || '';
  if (!secretKey) {
    return res.status(500).json({ error: 'Missing STRIPE_SECRET_KEY' });
  }

  try {
    const body = typeof req.body === 'string' ? JSON.parse(req.body) : (req.body || {});
    const plan = (body.plan || '').toString().toLowerCase();
    const userId = (body.userId || '').toString();
    const email = (body.email || '').toString();
    const successUrl = (body.successUrl || '').toString();
    const cancelUrl = (body.cancelUrl || '').toString();

    if (!['pro', 'business'].includes(plan)) {
      return res.status(400).json({ error: 'Invalid plan' });
    }
    if (!userId || !email || !successUrl || !cancelUrl) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const params = new URLSearchParams();
    params.set('mode', 'subscription');
    params.set('success_url', successUrl);
    params.set('cancel_url', cancelUrl);
    params.set('customer_email', email);
    params.set('client_reference_id', userId);
    params.set('line_items[0][quantity]', '1');
    params.set('subscription_data[metadata][plan]', plan);
    params.set('subscription_data[metadata][user_id]', userId);

    const priceId = plan === 'business' ? priceBusiness : pricePro;
    if (priceId) {
      params.set('line_items[0][price]', priceId);
    } else {
      // Temporary fallback pricing requested by user:
      // Pro = $20/month, Business = $30/month.
      const amount = plan === 'business' ? 3000 : 2000; // cents, USD
      params.set('line_items[0][price_data][currency]', 'usd');
      params.set('line_items[0][price_data][unit_amount]', String(amount));
      params.set('line_items[0][price_data][recurring][interval]', 'month');
      params.set('line_items[0][price_data][product_data][name]', `ANCODE ${plan === 'business' ? 'Business' : 'Pro'} Plan`);
      params.set('line_items[0][price_data][product_data][metadata][plan]', plan);
    }

    const stripeRes = await fetch('https://api.stripe.com/v1/checkout/sessions', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${secretKey}`,
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params.toString(),
    });

    const payload = await stripeRes.json();
    if (!stripeRes.ok) {
      return res.status(stripeRes.status).json({
        error: payload?.error?.message || 'Failed to create checkout session',
      });
    }
    return res.status(200).json({ url: payload.url });
  } catch (e) {
    return res.status(500).json({ error: e?.message || String(e) });
  }
};

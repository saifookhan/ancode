// Vercel serverless: reads env vars set in Vercel and returns public config for the Flutter app.
// Set SUPABASE_URL and SUPABASE_ANON_KEY in Vercel only – no GitHub Secrets needed.
module.exports = (req, res) => {
  res.setHeader('Cache-Control', 'public, max-age=60');
  res.status(200).json({
    supabaseUrl: process.env.SUPABASE_URL || '',
    supabaseAnonKey: process.env.SUPABASE_ANON_KEY || '',
    stripePublishableKey: process.env.STRIPE_PUBLISHABLE_KEY || null,
  });
};

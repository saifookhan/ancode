/// Stripe Checkout return URLs for the native app (custom scheme opens the app from Safari/Chrome).
class StripeCheckoutLinks {
  StripeCheckoutLinks._();

  /// Stripe replaces `{CHECKOUT_SESSION_ID}` when redirecting after payment.
  static String successUrl(String planLowercase) =>
      'ancode://payment?checkout=success&plan=$planLowercase&session_id={CHECKOUT_SESSION_ID}';

  static const String cancelUrl = 'ancode://payment?checkout=cancel';

  static bool isPaymentCallback(Uri uri) =>
      uri.scheme == 'ancode' && uri.host == 'payment' && uri.queryParameters.containsKey('checkout');
}

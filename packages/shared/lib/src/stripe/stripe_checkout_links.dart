import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

/// Stripe Checkout return URLs and opening the hosted checkout page.
class StripeCheckoutLinks {
  StripeCheckoutLinks._();

  /// Stripe replaces `{CHECKOUT_SESSION_ID}` when redirecting after payment.
  static String successUrl(String planLowercase) {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return '$origin/?checkout=success&plan=$planLowercase&session_id={CHECKOUT_SESSION_ID}';
    }
    return 'ancode://payment?checkout=success&plan=$planLowercase&session_id={CHECKOUT_SESSION_ID}';
  }

  static String get cancelUrl {
    if (kIsWeb) {
      return '${Uri.base.origin}/?checkout=cancel';
    }
    return 'ancode://payment?checkout=cancel';
  }

  static bool isPaymentCallback(Uri uri) =>
      uri.scheme == 'ancode' && uri.host == 'payment' && uri.queryParameters.containsKey('checkout');

  static Future<void> openCheckoutPage(String checkoutUrl) async {
    final uri = Uri.parse(checkoutUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) throw Exception('Cannot open checkout URL');
  }
}

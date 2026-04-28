import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String? _domain;
  static String? _stripePublishableKey;
  static String? _stripePublishableKeyFromApi;

  static String? _origin;

  /// Call when config was loaded from /api/config (e.g. Vercel env vars).
  static void setFromApi({String? stripePublishableKey}) {
    _stripePublishableKeyFromApi = stripePublishableKey;
  }

  static Future<void> initialize() async {
    // Web: use current origin so Vercel (or any host) gives the URL automatically
    if (kIsWeb) {
      _origin = Uri.base.origin;
      _domain = Uri.base.host;
    } else {
      _domain = dotenv.env['ANCODE_DOMAIN'] ?? 'ancode.vercel.app';
      _origin = 'https://$_domain';
    }
    try {
      _stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    } catch (_) {}
    _stripePublishableKey ??= _stripePublishableKeyFromApi ?? _stringFromEnv('STRIPE_PUBLISHABLE_KEY');
  }

  static String? _stringFromEnv(String name) {
    const v = String.fromEnvironment('STRIPE_PUBLISHABLE_KEY', defaultValue: '');
    return name == 'STRIPE_PUBLISHABLE_KEY' && v.isNotEmpty ? v : null;
  }

  static String get shortlinkBase => _origin ?? 'https://$_domain';
  static String shortlinkFor(String code) => '${shortlinkBase}/c/$code';
  static String? get stripePublishableKey => _stripePublishableKey;
}

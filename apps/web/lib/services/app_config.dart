import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String? _domain;
  static String? _stripePublishableKey;

  static String? _origin;

  static Future<void> initialize() async {
    // Web: use current origin so Vercel (or any host) gives the URL automatically
    if (kIsWeb) {
      _origin = Uri.base.origin;
      _domain = Uri.base.host;
    } else {
      _domain = dotenv.env['ANCODE_DOMAIN'] ?? 'ancode.vercel.app';
      _origin = 'https://$_domain';
    }
    _stripePublishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
  }

  static String get shortlinkBase => _origin ?? 'https://$_domain';
  static String shortlinkFor(String code) => '${shortlinkBase}/c/$code';
  static String? get stripePublishableKey => _stripePublishableKey;
}

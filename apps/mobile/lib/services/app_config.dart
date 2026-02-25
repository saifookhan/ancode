import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String? _domain;

  static Future<void> initialize() async {
    // Optional: only set if you need a custom shortlink domain (e.g. custom domain)
    _domain = dotenv.env['ANCODE_DOMAIN'] ?? 'ancode.vercel.app';
  }

  static String shortlinkFor(String code) =>
      'https://$_domain/c/$code';
}

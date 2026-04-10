import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  AppConfig._();

  static String? _domain;

  static Future<void> initialize() async {
    const fromDefineRaw =
        String.fromEnvironment('ANCODE_DOMAIN', defaultValue: '');
    final fromDefine = fromDefineRaw.trim();
    _domain = fromDefine.isNotEmpty
        ? fromDefine
        : (dotenv.env['ANCODE_DOMAIN'] ?? 'ancode.vercel.app');
  }

  static String shortlinkFor(String code) =>
      'https://$_domain/c/$code';
}

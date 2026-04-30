/// Resolves the Google Gemini API key for the chatbot.
///
/// Prefer `--dart-define=GEMINI_API_KEY=...` for release/CI so the key is not
/// bundled in assets; otherwise use [dotenvValue] from `flutter_dotenv`.
String resolveGeminiApiKey({String? dotenvValue}) {
  const fromDefine = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
  final trimmedDefine = fromDefine.trim();
  if (trimmedDefine.isNotEmpty) return trimmedDefine;
  return (dotenvValue ?? '').trim();
}

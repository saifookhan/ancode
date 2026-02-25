/// Placeholder for anti-fraud attestation (Apple App Attest / Play Integrity).
/// Optional behind feature flags.
class AttestationService {
  static bool _enabled = false;

  static bool get isEnabled => _enabled;

  static Future<String?> getAttestationToken() async {
    if (!_enabled) return null;
    // TODO: Apple App Attest or Play Integrity API
    return null;
  }
}

/// ANCODE code format constraints
const int kMaxCodeLength = 30;

/// Regex: uppercase letters + digits only, no spaces/symbols
final RegExp kCodeFormatPattern = RegExp(r'^[A-Z0-9]*$');

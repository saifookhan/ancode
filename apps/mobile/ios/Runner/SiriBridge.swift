import Flutter
import Foundation

/// ASCII fold for ANCODE ids (matches Dart `normalizeCodeInput` letter/digit pass, max 30).
enum AncodeCodeVoiceNormalizer {
  private static let maxLen = 30

  static func asciiFold(_ input: String) -> String {
    let upper = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    var out = ""
    for scalar in upper.unicodeScalars {
      guard out.count < maxLen else { break }
      let v = scalar.value
      let isDigit = v >= 0x30 && v <= 0x39
      let isUpper = v >= 0x41 && v <= 0x5a
      if isDigit || isUpper {
        out.append(String(scalar))
      }
    }
    return out
  }
}

enum SiriBridge {
  static let channelName = "ancode/siri"
  static let persistedCodeKey = "siri_search_code"
  /// Recent successful lookups help `EntityStringQuery.suggestedEntities()` satisfy Siri / Shortcuts resolution.
  static let recentCodesKey = "siri_recent_code_ids"
  private static let recentCodesMax = 12
  private static let searchHost = "search"
  private static let searchCodeQuery = "code"
  private static var pendingCode: String?
  private static weak var methodChannel: FlutterMethodChannel?

  static func configure(binaryMessenger: FlutterBinaryMessenger) {
    if pendingCode == nil {
      pendingCode = UserDefaults.standard.string(forKey: persistedCodeKey)
      if pendingCode != nil {
        UserDefaults.standard.removeObject(forKey: persistedCodeKey)
      }
    }

    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    methodChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInitialSiriCode":
        if pendingCode == nil {
          pendingCode = UserDefaults.standard.string(forKey: persistedCodeKey)
          if pendingCode != nil {
            UserDefaults.standard.removeObject(forKey: persistedCodeKey)
          }
        }
        let value = pendingCode
        pendingCode = nil
        result(value)
      case "rememberRecentCode":
        if let raw = call.arguments as? String {
          rememberSuccessfulLookupCode(raw)
          result(nil)
        } else {
          result(FlutterMethodNotImplemented)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// When an App Intent runs while Flutter is already alive, push the code on the channel
  /// so search runs without waiting for `getInitialSiriCode` / lifecycle resume.
  static func notifyIntentSearchCode(_ code: String) {
    guard let ch = methodChannel else { return }
    UserDefaults.standard.removeObject(forKey: persistedCodeKey)
    pendingCode = nil
    ch.invokeMethod("onSiriSearch", arguments: code)
  }

  static func rememberSuccessfulLookupCode(_ code: String) {
    let folded = AncodeCodeVoiceNormalizer.asciiFold(code)
    guard !folded.isEmpty else { return }
    var list = UserDefaults.standard.stringArray(forKey: recentCodesKey) ?? []
    list.removeAll { $0 == folded }
    list.insert(folded, at: 0)
    if list.count > recentCodesMax {
      list = Array(list.prefix(recentCodesMax))
    }
    UserDefaults.standard.set(list, forKey: recentCodesKey)
  }

  static func handleIncomingURL(_ url: URL) -> Bool {
    guard
      url.scheme?.lowercased() == "ancode",
      url.host?.lowercased() == searchHost
    else {
      return false
    }

    guard
      let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
      let code = components.queryItems?.first(where: { $0.name == searchCodeQuery })?.value?.trimmingCharacters(in: .whitespacesAndNewlines),
      !code.isEmpty
    else {
      return false
    }

    pendingCode = code
    UserDefaults.standard.removeObject(forKey: persistedCodeKey)
    methodChannel?.invokeMethod("onSiriSearch", arguments: code)
    return true
  }
}

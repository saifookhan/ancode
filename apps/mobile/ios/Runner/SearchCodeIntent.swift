import AppIntents
import Foundation

@available(iOS 16.0, *)
struct SearchCodeIntent: AppIntent {
  static var title: LocalizedStringResource = "Search Code"
  static var description = IntentDescription("Search an ANCODE code in the app.")
  static var openAppWhenRun: Bool = true

  @Parameter(title: "Code")
  var code: String

  func perform() async throws -> some IntentResult {
    let cleanedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanedCode.isEmpty else {
      throw $code.needsValueError("Please provide a code to search.")
    }

    UserDefaults.standard.set(cleanedCode, forKey: SiriBridge.persistedCodeKey)
    return .result()
  }
}

@available(iOS 16.0, *)
struct AncodeShortcutsProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SearchCodeIntent(),
      phrases: [
        "Search code \(\.$code) in \(.applicationName)",
        "Find code \(\.$code) in \(.applicationName)",
        "Look up code \(\.$code) in \(.applicationName)",
        "Cerca codice \(\.$code) in \(.applicationName)",
        "Trova codice \(\.$code) in \(.applicationName)",
        "Cerca il codice \(\.$code) su \(.applicationName)",
      ],
      shortTitle: "Search Code",
      systemImageName: "magnifyingglass"
    )
  }
}

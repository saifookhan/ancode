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
        // English — natural phrasing with app name and shorter “on ANCODE” variants
        "Search \(.code) in \(.applicationName)",
        "Open \(.code) in \(.applicationName)",
        "Show \(.code) in \(.applicationName)",
        "Go to \(.code) in \(.applicationName)",
        "Search \(.code) on \(.applicationName)",
        "Open \(.code) on \(.applicationName)",
        "Show \(.code) on \(.applicationName)",
        "Go to \(.code) on \(.applicationName)",
        "Search \(.code) on ANCODE",
        "Open \(.code) on ANCODE",
        "Show \(.code) on ANCODE",
        "Go to \(.code) on ANCODE",
        "Search code in \(.applicationName)",
        "Find a code in \(.applicationName)",
        "Look up a code in \(.applicationName)",
        // Italian
        "Cerca \(.code) in \(.applicationName)",
        "Apri \(.code) in \(.applicationName)",
        "Mostra \(.code) in \(.applicationName)",
        "Vai a \(.code) in \(.applicationName)",
        "Cerca \(.code) su \(.applicationName)",
        "Apri \(.code) su \(.applicationName)",
        "Mostra \(.code) su \(.applicationName)",
        "Vai a \(.code) su \(.applicationName)",
        "Cerca \(.code) su ANCODE",
        "Apri \(.code) su ANCODE",
        "Cerca un codice in \(.applicationName)",
        "Trova un codice in \(.applicationName)",
        "Cerca codice su \(.applicationName)",
      ],
      shortTitle: "Search Code",
      systemImageName: "magnifyingglass"
    )
  }
}

import AppIntents
import Foundation

@available(iOS 16.0, *)
struct SearchCodeIntent: AppIntent {
  static var title: LocalizedStringResource = "Search Code"
  static var description = IntentDescription("Search an ANCODE code in the app.")
  static var openAppWhenRun: Bool = true

  /// Plain `String` cannot appear in App Shortcut spoken phrases (only `AppEntity` / `AppEnum`).
  /// Shortcuts and Siri collect this value after the user picks the action or when prompted.
  @Parameter(
    title: "Code",
    description: "The ANCODE to look up.",
    requestValueDialog: IntentDialog("Which code do you want to search?")
  )
  var code: String

  static var parameterSummary: some ParameterSummary {
    Summary("Search for \(\.$code)")
  }

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
        // App Store validation: only `AppEntity` / `AppEnum` may appear in phrases besides
        // `\(.applicationName)`, and every utterance must include `\(.applicationName)` exactly once.
        "Search for a code in \(.applicationName)",
        "Look up a code in \(.applicationName)",
        "Find a code in \(.applicationName)",
        "Open a code in \(.applicationName)",
        "Show a code in \(.applicationName)",
        "Go to a code in \(.applicationName)",
        "Search ANCODE in \(.applicationName)",
        "Open ANCODE in \(.applicationName)",
        "Show ANCODE in \(.applicationName)",
        "Go to ANCODE in \(.applicationName)",
        "Search the ANCODE app in \(.applicationName)",
        "Open the ANCODE app in \(.applicationName)",
        // Italian
        "Cerca un codice in \(.applicationName)",
        "Trova un codice in \(.applicationName)",
        "Cerca codice in \(.applicationName)",
        "Apri un codice in \(.applicationName)",
        "Mostra un codice in \(.applicationName)",
        "Vai al codice in \(.applicationName)",
        "Cerca ANCODE in \(.applicationName)",
        "Apri ANCODE in \(.applicationName)",
        "Mostra ANCODE in \(.applicationName)",
        "Vai a ANCODE in \(.applicationName)",
        "Cerca con ANCODE in \(.applicationName)",
      ],
      shortTitle: "Search Code",
      systemImageName: "magnifyingglass"
    )
  }
}

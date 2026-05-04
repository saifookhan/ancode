import AppIntents
import Foundation

// MARK: - Code entity (required for spoken code in Siri phrases)

/// Resolves a user-spoken code (e.g. "CASA") so phrases like "Search CASA on ANCODE" are valid.
/// Plain `String` parameters cannot appear in App Shortcut phrases; only `AppEntity` / `AppEnum` can.
@available(iOS 16.0, *)
struct SearchableCodeEntity: AppEntity {
  static var typeDisplayRepresentation: TypeDisplayRepresentation = "ANCODE"

  static var defaultQuery = SearchableCodeEntityQuery()

  var id: String

  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(title: LocalizedStringResource(stringLiteral: id))
  }
}

@available(iOS 16.0, *)
struct SearchableCodeEntityQuery: EntityStringQuery {
  func entities(matching string: String) async throws -> [SearchableCodeEntity] {
    let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    guard !trimmed.isEmpty else { return [] }
    return [SearchableCodeEntity(id: trimmed)]
  }

  func entities(for identifiers: [SearchableCodeEntity.ID]) async throws -> [SearchableCodeEntity] {
    identifiers
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
      .filter { !$0.isEmpty }
      .map { SearchableCodeEntity(id: $0) }
  }

  func suggestedEntities() async throws -> [SearchableCodeEntity] {
    []
  }
}

// MARK: - Intent

@available(iOS 16.0, *)
struct SearchCodeIntent: AppIntent {
  static var title: LocalizedStringResource = "Search Code"
  static var description = IntentDescription("Search an ANCODE code in the app.")
  static var openAppWhenRun: Bool = true

  @Parameter(
    title: "Code",
    description: "The ANCODE to look up.",
    requestValueDialog: IntentDialog("Which code do you want to search?")
  )
  var code: SearchableCodeEntity

  static var parameterSummary: some ParameterSummary {
    Summary("Search for \(\.$code)")
  }

  func perform() async throws -> some IntentResult {
    let cleanedCode = code.id.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !cleanedCode.isEmpty else {
      throw $code.needsValueError("Please provide a code to search.")
    }

    UserDefaults.standard.set(cleanedCode, forKey: SiriBridge.persistedCodeKey)
    SiriBridge.notifyIntentSearchCode(cleanedCode)
    return .result()
  }
}

@available(iOS 16.0, *)
struct AncodeShortcutsProvider: AppShortcutsProvider {
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SearchCodeIntent(code: SearchableCodeEntity(id: "")),
      phrases: [
        // `\(.applicationName)` must appear exactly once per phrase (App Store / NLU rules).
        // `\(.code)` is allowed because `SearchableCodeEntity` is an `AppEntity`.
        "Search \(.code) on \(.applicationName)",
        "Search \(.code) in \(.applicationName)",
        "Look up \(.code) on \(.applicationName)",
        "Look up \(.code) in \(.applicationName)",
        "Find \(.code) on \(.applicationName)",
        "Find \(.code) in \(.applicationName)",
        "Open \(.code) on \(.applicationName)",
        "Open \(.code) in \(.applicationName)",
        "Show \(.code) on \(.applicationName)",
        "Show \(.code) in \(.applicationName)",
        "Go to \(.code) on \(.applicationName)",
        "Go to \(.code) in \(.applicationName)",
        // Phrases that collect the code in a follow-up prompt (no inline entity)
        "Search for a code in \(.applicationName)",
        "Look up a code in \(.applicationName)",
        "Find a code in \(.applicationName)",
        "Open a code in \(.applicationName)",
        "Show a code in \(.applicationName)",
        "Go to a code in \(.applicationName)",
        // Italian — inline code
        "Cerca \(.code) su \(.applicationName)",
        "Cerca \(.code) in \(.applicationName)",
        "Trova \(.code) su \(.applicationName)",
        "Trova \(.code) in \(.applicationName)",
        "Apri \(.code) su \(.applicationName)",
        "Apri \(.code) in \(.applicationName)",
        "Mostra \(.code) su \(.applicationName)",
        "Mostra \(.code) in \(.applicationName)",
        "Vai a \(.code) su \(.applicationName)",
        "Vai a \(.code) in \(.applicationName)",
        // Italian — prompt for code
        "Cerca un codice in \(.applicationName)",
        "Trova un codice in \(.applicationName)",
        "Cerca codice in \(.applicationName)",
        "Apri un codice in \(.applicationName)",
        "Mostra un codice in \(.applicationName)",
        "Vai al codice in \(.applicationName)",
      ],
      shortTitle: "Search Code",
      systemImageName: "magnifyingglass"
    )
  }
}

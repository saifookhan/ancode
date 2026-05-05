import AppIntents
import Foundation

// MARK: - Code entity (required for spoken code in Siri phrases)

/// Resolves a user-spoken code (e.g. "CASA") so phrases like "Search CASA on ANCODE" are valid.
/// Plain `String` parameters cannot appear in App Shortcut phrases; only `AppEntity` / `AppEnum` can.
@available(iOS 16.0, *)
struct SearchableCodeEntity: AppEntity {
  /// Avoid the same label as the app name token so Siri does not treat this slot as “the app”.
  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "Lookup code")
  }

  static var defaultQuery = SearchableCodeEntityQuery()

  var id: String

  /// `String.LocalizationValue` interpolation for the spoken code (not `LocalizedStringResource = "\\(id)"`).
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "\(id)",
      subtitle: "Letters or digits"
    )
  }
}

@available(iOS 16.0, *)
struct SearchableCodeEntityQuery: EntityStringQuery {
  func entities(matching string: String) async throws -> [SearchableCodeEntity] {
    let folded = AncodeCodeVoiceNormalizer.asciiFold(string)
    guard !folded.isEmpty else { return [] }
    return [SearchableCodeEntity(id: folded)]
  }

  func entities(for identifiers: [SearchableCodeEntity.ID]) async throws -> [SearchableCodeEntity] {
    identifiers
      .map { AncodeCodeVoiceNormalizer.asciiFold($0) }
      .filter { !$0.isEmpty }
      .map { SearchableCodeEntity(id: $0) }
  }

  func suggestedEntities() async throws -> [SearchableCodeEntity] {
    let list = UserDefaults.standard.stringArray(forKey: SiriBridge.recentCodesKey) ?? []
    return list.map { SearchableCodeEntity(id: $0) }
  }
}

// MARK: - Intent

@available(iOS 16.0, *)
struct SearchCodeIntent: AppIntent {
  static var title: LocalizedStringResource {
    LocalizedStringResource(stringLiteral: "Search Code")
  }

  static var description = IntentDescription("Search an ANCODE code in the app.")

  static var openAppWhenRun: Bool = true

  @Parameter(
    title: "Code",
    description: "The ANCODE to look up."
  )
  var code: SearchableCodeEntity

  static var parameterSummary: some ParameterSummary {
    Summary("Search for \(\.$code)")
  }

  init() {}

  func perform() async throws -> some IntentResult {
    let cleanedCode = AncodeCodeVoiceNormalizer.asciiFold(code.id)
    guard !cleanedCode.isEmpty else {
      throw $code.needsValueError("Please provide a code to search.")
    }

    UserDefaults.standard.set(cleanedCode, forKey: SiriBridge.persistedCodeKey)
    SiriBridge.notifyIntentSearchCode(cleanedCode)
    SiriBridge.rememberSuccessfulLookupCode(cleanedCode)
    return .result()
  }
}

// MARK: - Shortcuts

/// Full phrase list as a single compile-time `static let` (referenced from `@AppShortcutsBuilder`) so
/// phrases stay maintainable and macros see stable `AppShortcutPhrase` sources.
@available(iOS 16.0, *)
private enum AncodeSearchShortcutPhrases {
  typealias Phrase = AppShortcutPhrase<SearchCodeIntent>

  static let merged: [Phrase] = [
    "Search \(\.$code) on \(.applicationName)",
    "Search \(\.$code) in \(.applicationName)",
    "Look up \(\.$code) on \(.applicationName)",
    "Look up \(\.$code) in \(.applicationName)",
    "Find \(\.$code) on \(.applicationName)",
    "Find \(\.$code) in \(.applicationName)",
    "Open \(\.$code) on \(.applicationName)",
    "Open \(\.$code) in \(.applicationName)",
    "Show \(\.$code) on \(.applicationName)",
    "Show \(\.$code) in \(.applicationName)",
    "Go to \(\.$code) on \(.applicationName)",
    "Go to \(\.$code) in \(.applicationName)",
    "Search \(\.$code) on the \(.applicationName) app",
    "Open \(\.$code) on the \(.applicationName) app",
    "Show \(\.$code) on the \(.applicationName) app",
    "Go to \(\.$code) on the \(.applicationName) app",
    "Cerca \(\.$code) su \(.applicationName)",
    "Cerca \(\.$code) in \(.applicationName)",
    "Trova \(\.$code) su \(.applicationName)",
    "Trova \(\.$code) in \(.applicationName)",
    "Apri \(\.$code) su \(.applicationName)",
    "Apri \(\.$code) in \(.applicationName)",
    "Mostra \(\.$code) su \(.applicationName)",
    "Mostra \(\.$code) in \(.applicationName)",
    "Vai a \(\.$code) su \(.applicationName)",
    "Vai a \(\.$code) in \(.applicationName)",
    "Search for a code in \(.applicationName)",
    "Look up a code in \(.applicationName)",
    "Find a code in \(.applicationName)",
    "Open a code in \(.applicationName)",
    "Show a code in \(.applicationName)",
    "Go to a code in \(.applicationName)",
    "Cerca un codice in \(.applicationName)",
    "Trova un codice in \(.applicationName)",
    "Cerca codice in \(.applicationName)",
    "Apri un codice in \(.applicationName)",
    "Mostra un codice in \(.applicationName)",
    "Vai al codice in \(.applicationName)",
  ]
}

/// Apple: `@AppShortcutsBuilder static var appShortcuts: [AppShortcut]`. Use one `AppShortcut` inside the
/// builder (no raw `[AppShortcut]` literal without the attribute).
@available(iOS 16.0, *)
struct AncodeShortcutsProvider: AppShortcutsProvider {
  @AppShortcutsBuilder
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SearchCodeIntent(),
      phrases: AncodeSearchShortcutPhrases.merged,
      shortTitle: "Search code",
      systemImageName: "magnifyingglass"
    )
  }
}

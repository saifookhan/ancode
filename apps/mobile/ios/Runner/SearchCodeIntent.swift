import AppIntents
import Foundation

// MARK: - Code entity (required for spoken code in Siri phrases)

/// Resolves a user-spoken code (e.g. "CASA") so phrases like "Search CASA on ANCODE" are valid.
/// Plain `String` parameters cannot appear in App Shortcut phrases; only `AppEntity` / `AppEnum` can.
@available(iOS 16.0, *)
struct SearchableCodeEntity: AppEntity {
  /// Avoid the same label as the app name token so Siri does not treat this slot as “the app”.
  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: LocalizedStringResource("Lookup code"))
  }

  static var defaultQuery = SearchableCodeEntityQuery()

  var id: String

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
  static var title: LocalizedStringResource = "Search Code"
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

// MARK: - Shortcuts (Xcode 16+ needs `AppShortcutPhrase` + `@AppShortcutsBuilder` for multiple shortcuts)

@available(iOS 16.0, *)
enum AncodeSearchShortcutPhrases {
  typealias Phrase = AppShortcutPhrase<SearchCodeIntent>

  /// Phrases that include `\(\.$code)` so Siri can bind the spoken code in one utterance.
  static func inlineList() -> [Phrase] {
    var list = [Phrase]()
    list.append("Search \(\.$code) on \(.applicationName)")
    list.append("Search \(\.$code) in \(.applicationName)")
    list.append("Look up \(\.$code) on \(.applicationName)")
    list.append("Look up \(\.$code) in \(.applicationName)")
    list.append("Find \(\.$code) on \(.applicationName)")
    list.append("Find \(\.$code) in \(.applicationName)")
    list.append("Open \(\.$code) on \(.applicationName)")
    list.append("Open \(\.$code) in \(.applicationName)")
    list.append("Show \(\.$code) on \(.applicationName)")
    list.append("Show \(\.$code) in \(.applicationName)")
    list.append("Go to \(\.$code) on \(.applicationName)")
    list.append("Go to \(\.$code) in \(.applicationName)")
    list.append("Search \(\.$code) on the \(.applicationName) app")
    list.append("Open \(\.$code) on the \(.applicationName) app")
    list.append("Show \(\.$code) on the \(.applicationName) app")
    list.append("Go to \(\.$code) on the \(.applicationName) app")
    list.append("Cerca \(\.$code) su \(.applicationName)")
    list.append("Cerca \(\.$code) in \(.applicationName)")
    list.append("Trova \(\.$code) su \(.applicationName)")
    list.append("Trova \(\.$code) in \(.applicationName)")
    list.append("Apri \(\.$code) su \(.applicationName)")
    list.append("Apri \(\.$code) in \(.applicationName)")
    list.append("Mostra \(\.$code) su \(.applicationName)")
    list.append("Mostra \(\.$code) in \(.applicationName)")
    list.append("Vai a \(\.$code) su \(.applicationName)")
    list.append("Vai a \(\.$code) in \(.applicationName)")
    return list
  }

  /// Phrases without an inline code slot (second shortcut) so NLU does not mix them with inline phrases.
  static func promptOnlyList() -> [Phrase] {
    var list = [Phrase]()
    list.append("Search for a code in \(.applicationName)")
    list.append("Look up a code in \(.applicationName)")
    list.append("Find a code in \(.applicationName)")
    list.append("Open a code in \(.applicationName)")
    list.append("Show a code in \(.applicationName)")
    list.append("Go to a code in \(.applicationName)")
    list.append("Cerca un codice in \(.applicationName)")
    list.append("Trova un codice in \(.applicationName)")
    list.append("Cerca codice in \(.applicationName)")
    list.append("Apri un codice in \(.applicationName)")
    list.append("Mostra un codice in \(.applicationName)")
    list.append("Vai al codice in \(.applicationName)")
    return list
  }
}

@available(iOS 16.0, *)
struct AncodeShortcutsProvider: AppShortcutsProvider {
  @AppShortcutsBuilder
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SearchCodeIntent(),
      phrases: AncodeSearchShortcutPhrases.inlineList(),
      shortTitle: LocalizedStringResource("Search code"),
      systemImageName: "magnifyingglass"
    )
    AppShortcut(
      intent: SearchCodeIntent(),
      phrases: AncodeSearchShortcutPhrases.promptOnlyList(),
      shortTitle: LocalizedStringResource("Pick code"),
      systemImageName: "list.bullet"
    )
  }
}

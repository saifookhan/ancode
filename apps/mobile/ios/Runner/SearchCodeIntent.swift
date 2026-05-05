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

  /// Static copy only: dynamic `"\(id)"` in `DisplayRepresentation` interacts badly with Xcode 26
  /// archive + App Intents macros (`LocalizedStringResource` diagnostics). The resolved `id` is still
  /// the entity value Siri binds; this only affects Shortcuts-picker labels.
  var displayRepresentation: DisplayRepresentation {
    DisplayRepresentation(
      title: "Code",
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

/// `AppShortcutsProvider` requires `@AppShortcutsBuilder` and `[AppShortcut]` (see Apple docs). Omitting
/// the attribute makes a raw `[AppShortcut]` literal fail to match the protocol (`AppShortcut` vs array).
/// Phrases are kept smaller + inlined to reduce Xcode 26 `LocalizedStringResource` macro failures.
@available(iOS 16.0, *)
struct AncodeShortcutsProvider: AppShortcutsProvider {
  @AppShortcutsBuilder
  static var appShortcuts: [AppShortcut] {
    AppShortcut(
      intent: SearchCodeIntent(),
      phrases: [
        "Search \(\.$code) on \(.applicationName)",
        "Search \(\.$code) in \(.applicationName)",
        "Look up \(\.$code) on \(.applicationName)",
        "Look up \(\.$code) in \(.applicationName)",
        "Open \(\.$code) on \(.applicationName)",
        "Open \(\.$code) in \(.applicationName)",
        "Search \(\.$code) on the \(.applicationName) app",
        "Search for a code in \(.applicationName)",
      ],
      shortTitle: "Search code",
      systemImageName: "magnifyingglass"
    )
  }
}

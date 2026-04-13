import Flutter
import Foundation

enum SiriBridge {
  static let channelName = "ancode/siri"
  private static let searchHost = "search"
  private static let searchCodeQuery = "code"
  private static var pendingCode: String?
  private static weak var methodChannel: FlutterMethodChannel?

  static func configure(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: binaryMessenger)
    methodChannel = channel
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "getInitialSiriCode":
        let value = pendingCode
        pendingCode = nil
        result(value)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
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
    methodChannel?.invokeMethod("onSiriSearch", arguments: code)
    return true
  }
}

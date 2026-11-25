import Foundation
import WebKit

/// Verification-build logger: receives `mw` messages from spike.js and appends one line per
/// event to ~/Library/Logs/MessengerWrapper/spike.log as "<ISO-8601 timestamp> <type> <json>".
final class SpikeLog: NSObject, WKScriptMessageHandler {
    static let handlerName: String = "mw"
    private static let maxLineLength: Int = 4000

    private let fileURL: URL
    private let formatter: ISO8601DateFormatter

    override init() {
        let directory: URL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("MessengerWrapper", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("spike.log", isDirectory: false)

        let formatter: ISO8601DateFormatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        self.formatter = formatter
        super.init()
    }

    func install(into controller: WKUserContentController) {
        controller.add(self, name: SpikeLog.handlerName)
        guard let url: URL = Bundle.main.url(forResource: "spike", withExtension: "js"),
              let source: String = try? String(contentsOf: url, encoding: .utf8) else {
            write(event: "app", detail: "spike.js not found in app bundle")
            return
        }
        let script: WKUserScript = WKUserScript(source: source,
                                                injectionTime: .atDocumentStart,
                                                forMainFrameOnly: true)
        controller.addUserScript(script)
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        guard message.frameInfo.isMainFrame else { return }

        guard var fields: [String: Any] = message.body as? [String: Any] else {
            write(event: "unknown", detail: String(describing: message.body))
            return
        }
        let type: String = (fields["type"] as? String) ?? "unknown"
        fields.removeValue(forKey: "type")
        write(event: type, detail: SpikeLog.json(fields))
    }

    func write(event: String, detail: String) {
        var line: String = formatter.string(from: Date()) + " " + event + " " + detail
        line = line.replacingOccurrences(of: "\n", with: " ")
        if line.count > SpikeLog.maxLineLength {
            line = String(line.prefix(SpikeLog.maxLineLength)) + "..."
        }
        line += "\n"
        append(Data(line.utf8))
    }

    private func append(_ data: Data) {
        if !FileManager.default.fileExists(atPath: fileURL.path) {
            FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        }
        guard let handle: FileHandle = try? FileHandle(forWritingTo: fileURL) else { return }
        defer { try? handle.close() }
        do {
            _ = try handle.seekToEnd()
            try handle.write(contentsOf: data)
        } catch {
            // Logging must never take the app down.
        }
    }

    private static func json(_ object: [String: Any]) -> String {
        guard JSONSerialization.isValidJSONObject(object),
              let data: Data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let text: String = String(data: data, encoding: .utf8) else {
            return String(describing: object)
        }
        return text
    }
}

import Foundation

/// Picks where a download is saved: a safe file name inside the downloads
/// directory that does not overwrite an existing file.
public enum DownloadNamer {
    private static let fallbackName = "download"
    private static let removedCharacters = CharacterSet.controlCharacters.union(CharacterSet(charactersIn: "/:"))

    /// The destination for a download the page suggests calling `suggested`.
    ///
    /// Only the last path component of `suggested` is kept, without control
    /// characters, `/` or `:`. An empty name, `.` or `..` becomes `download`;
    /// a name starting with `.` is prefixed with `download` so the file is not
    /// hidden. When `exists` reports a name as taken, ` (1)`, ` (2)`, ... is
    /// added before the extension. Only `exists` is consulted, never the file
    /// system.
    public static func destination(suggested: String, in directory: URL,
                                   exists: (URL) -> Bool) -> URL {
        let name = safeName(suggested)
        var url = directory.appendingPathComponent(name, isDirectory: false)
        var counter = 1
        while exists(url) {
            url = directory.appendingPathComponent(numbered(name, counter), isDirectory: false)
            counter += 1
        }
        return url
    }

    private static func safeName(_ suggested: String) -> String {
        // Splitting drops empty components, so "a/b/" yields "b" and "/" none.
        let last = suggested.split(separator: "/").last.map(String.init) ?? ""
        var scalars = String.UnicodeScalarView()
        scalars.append(contentsOf: last.unicodeScalars.filter { !removedCharacters.contains($0) })
        let name = String(scalars)
        if name.isEmpty || name == "." || name == ".." {
            return fallbackName
        }
        if name.hasPrefix(".") {
            return fallbackName + name
        }
        return name
    }

    /// `name` with ` (counter)` before its last extension: `a (1).pdf`,
    /// `a.tar (1).gz`, `name (1)`.
    private static func numbered(_ name: String, _ counter: Int) -> String {
        if let dot = name.lastIndex(of: "."), dot != name.startIndex, name.index(after: dot) != name.endIndex {
            return "\(name[..<dot]) (\(counter))\(name[dot...])"
        }
        return "\(name) (\(counter))"
    }
}

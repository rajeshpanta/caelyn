import Foundation

/// A file she picked, decoded once and shared by every detector and parser.
///
/// Detection asks several questions of the same bytes ("is this Clue's JSON?",
/// "does this have a date column?"), and each answer needs the file parsed. Doing
/// that once here keeps a large export from being re-parsed per candidate source,
/// and keeps every source looking at exactly the same interpretation of the file.
struct ImportPayload {

    /// Original filename, lowercased. A hint only — never the deciding evidence,
    /// because a filename is the easiest thing in the world to be wrong.
    let filename: String
    let data: Data

    init(filename: String, data: Data) {
        self.filename = filename.lowercased()
        self.data = data
    }

    // MARK: - Text

    /// UTF-8 first, then the encodings a spreadsheet export realistically uses.
    /// Nil means the file is not text at all — a PDF, an image, a zip.
    private(set) lazy var text: String? = decodedText()

    /// Non-lazy so the other lazy properties can use it without needing a mutable
    /// copy of `self` to touch `text` mid-initialisation.
    private func decodedText() -> String? {
        if let utf8 = String(data: data, encoding: .utf8) { return stripBOM(utf8) }
        for encoding: String.Encoding in [.utf16, .isoLatin1, .windowsCP1252] {
            if let decoded = String(data: data, encoding: encoding) { return stripBOM(decoded) }
        }
        return nil
    }

    private func stripBOM(_ string: String) -> String {
        string.hasPrefix("\u{FEFF}") ? String(string.dropFirst()) : string
    }

    // MARK: - Structured views

    private(set) lazy var json: Any? = {
        guard looksLikeJSON else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
    }()

    /// Rows including the header, RFC 4180 parsed. Nil when the file isn't text.
    private(set) lazy var csvRows: [[String]]? = {
        guard !looksLikeJSON, let text = decodedText() else { return nil }
        let rows = CSVReader.parse(text)
        return rows.isEmpty ? nil : rows
    }()

    /// Header row, trimmed and lowercased — the shape most detectors match on.
    private(set) lazy var csvHeaders: [String] = {
        guard !looksLikeJSON, let text = decodedText(),
              let header = CSVReader.parse(text).first else { return [] }
        return header.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
    }()

    /// Cheap structural check so a 40 MB CSV is never handed to JSONSerialization.
    var looksLikeJSON: Bool {
        for byte in data.prefix(64) {
            switch byte {
            case 0x20, 0x09, 0x0A, 0x0D, 0xEF, 0xBB, 0xBF: continue   // whitespace / BOM
            case UInt8(ascii: "["), UInt8(ascii: "{"):      return true
            default:                                        return false
            }
        }
        return false
    }

    var isEmpty: Bool { data.isEmpty }
}

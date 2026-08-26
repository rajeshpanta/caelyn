import Foundation

/// RFC 4180 CSV reading: quoted fields, escaped quotes, embedded newlines, and
/// both line-ending conventions.
///
/// Lifted out of `ImportService` so the file-import adapters and the original
/// Settings importer share one parser rather than drifting apart. Behaviour is
/// unchanged — the existing CSV tests pass against it untouched.
enum CSVReader {

    static func parse(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var iterator = text.startIndex

        func endField() { row.append(field); field = "" }
        func endRow() {
            endField()
            // A trailing newline produces one empty field; that is not a row.
            if !(row.count == 1 && row[0].isEmpty) { rows.append(row) }
            row = []
        }

        while iterator < text.endIndex {
            let character = text[iterator]
            if inQuotes {
                if character == "\"" {
                    let next = text.index(after: iterator)
                    if next < text.endIndex, text[next] == "\"" {
                        field.append("\"")
                        iterator = next
                    } else {
                        inQuotes = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    inQuotes = true
                case ",":
                    endField()
                // Swift treats CRLF as a single Character, so a file saved on
                // Windows — which is most files exported from a spreadsheet —
                // never matches a bare "\n" and the whole file reads as one row.
                case "\n", "\r\n", "\r":
                    endRow()
                default:
                    field.append(character)
                }
            }
            iterator = text.index(after: iterator)
        }
        if !field.isEmpty || !row.isEmpty { endRow() }
        return rows
    }

    /// Index every header name to its column. Later duplicates are dropped rather
    /// than silently shadowing the first — a file with two `date` columns keeps
    /// the leftmost, which is the one a spreadsheet user means.
    static func columnIndex(headers: [String]) -> [String: Int] {
        var index: [String: Int] = [:]
        for (position, name) in headers.enumerated() where index[name] == nil {
            index[name] = position
        }
        return index
    }
}

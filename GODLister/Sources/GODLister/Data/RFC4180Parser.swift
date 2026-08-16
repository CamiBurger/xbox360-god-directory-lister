import Foundation

/// Minimal RFC4180 CSV parser: quoted fields (with embedded commas/newlines),
/// `""` as an escaped quote, and `\r\n` or `\n` as unquoted record separators.
///
/// Iterates Unicode scalars, not Characters: Swift's Character grapheme
/// clustering treats "\r\n" as a SINGLE Character, so a naive
/// character-by-character scan never sees a standalone `\r` to split on -
/// the real bundled DLC catalog uses CRLF line endings and would silently
/// parse as one giant field/record without this.
enum RFC4180Parser {
    static func parse(_ text: Substring) -> [[String]] {
        var records: [[String]] = []
        var currentRecord: [String] = []
        var field = ""
        var inQuotes = false

        let scalars = Array(text.unicodeScalars)
        var i = 0
        let quote: Unicode.Scalar = "\""
        let comma: Unicode.Scalar = ","
        let cr: Unicode.Scalar = "\r"
        let lf: Unicode.Scalar = "\n"

        while i < scalars.count {
            let ch = scalars[i]
            if inQuotes {
                if ch == quote {
                    if i + 1 < scalars.count, scalars[i + 1] == quote {
                        field.unicodeScalars.append(quote)
                        i += 2
                    } else {
                        inQuotes = false
                        i += 1
                    }
                } else {
                    field.unicodeScalars.append(ch)
                    i += 1
                }
            } else {
                switch ch {
                case quote:
                    inQuotes = true
                    i += 1
                case comma:
                    currentRecord.append(field)
                    field = ""
                    i += 1
                case cr, lf:
                    currentRecord.append(field)
                    field = ""
                    records.append(currentRecord)
                    currentRecord = []
                    if ch == cr, i + 1 < scalars.count, scalars[i + 1] == lf {
                        i += 2
                    } else {
                        i += 1
                    }
                default:
                    field.unicodeScalars.append(ch)
                    i += 1
                }
            }
        }

        // Trailing record with no final line break.
        if !field.isEmpty || !currentRecord.isEmpty {
            currentRecord.append(field)
            records.append(currentRecord)
        }

        return records
    }
}

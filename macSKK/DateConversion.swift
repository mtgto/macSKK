// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/**
 * 日付の変換の定義
 */
struct DateConversion: Identifiable {
    enum DateConversionCalendar: String, CaseIterable {
        case gregorian = "gregorian"
        case japanese = "japanese"

        var calendar: Calendar {
            switch self {
            case .gregorian:
                return Calendar(identifier: .gregorian)
            case .japanese:
                return Calendar(identifier: .japanese)
            }
        }

        var localized: String {
            // CodingKeyのstringValueを使う
            // String#capitalizedは先頭以外の大文字を小文字に変換するのでLocalized.stringsでのキーに注意
            String(localized: LocalizedStringResource(stringLiteral: "Calendar\(rawValue.capitalized)"))
        }
    }

    enum DateConversionLocale: String, CaseIterable {
        case jaJP = "ja_JP"
        case enUS = "en_US"

        var locale: Locale {
            switch self {
            case .jaJP:
                return Locale(identifier: "ja_JP")
            case .enUS:
                return Locale(identifier: "en_US")
            }
        }

        var localized: String {
            // CodingKeyのstringValueを使う
            // String#capitalizedは先頭以外の大文字を小文字に変換するのでLocalized.stringsでのキーに注意
            String(localized: LocalizedStringResource(stringLiteral: "Locale\(rawValue.capitalized)"))
        }
    }

    let id: UUID
    /// DateFormatter.dateFormat形式の文字列。
    /// 詳細はUnicode Technical Standard #35のDate Format Patternsを参照。
    /// https://unicode.org/reports/tr35/tr35-dates.html#Date_Format_Patterns
    let format: String
    /// Locale.identifier相当の文字列。
    /// 曜日の表記などに影響する。`"ja_JP"` または `"en_US"`
    let locale: DateConversionLocale
    /// 西暦・和暦の表記などに影響する。Calendar.Identifierのうちから選択。"gregorian" または "japanese"
    let calendar: DateConversionCalendar
    let dateFormatter: DateFormatter

    init(id: UUID = UUID(), format: String, locale: DateConversion.DateConversionLocale, calendar: DateConversion.DateConversionCalendar) {
        self.id = id
        self.format = format
        self.locale = locale
        self.calendar = calendar
        self.dateFormatter = {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = format
            dateFormatter.locale = locale.locale
            dateFormatter.calendar = calendar.calendar
            return dateFormatter
        }()
    }

    // UserDefaultsからのデコード用
    init?(dict: [String: Any]) {
        guard let format = dict["format"] as? String,
            let localeString = dict["locale"] as? String,
            let calendarString = dict["calendar"] as? String,
            let locale = DateConversionLocale(rawValue: localeString),
            let calendar = DateConversionCalendar(rawValue: calendarString)
        else { return nil }
        self.init(format: format, locale: locale, calendar: calendar)
    }

    func encode() -> [String: Any] {
        return [
            "format": format,
            "locale": locale.rawValue,
            "calendar": calendar.rawValue,
        ]
    }

    /// 日付変換の読み部分。通常の読みに加えて現在時間からの差分を持つ
    struct Yomi: Identifiable, Hashable {
        enum RelativeTime: String, CaseIterable {
            case now
            case yesterday
            case tomorrow

            var localized: String {
                // CodingKeyのstringValueを使う
                // String#capitalizedは先頭以外の大文字を小文字に変換するのでLocalized.stringsでのキーに注意
                String(localized: LocalizedStringResource(stringLiteral: "DateYomiRelative\(rawValue.capitalized)"))
            }
        }

        let id: UUID
        let yomi: String
        let relative: RelativeTime

        init(id: UUID = UUID(), yomi: String, relative: RelativeTime) {
            self.id = id
            self.yomi = yomi
            self.relative = relative
        }

        // UserDefaultsからのデコード用
        init?(dict: [String: Any]) {
            guard let yomi = dict["yomi"] as? String,
                let relativeString = dict["relative"] as? String,
                let relative = RelativeTime(rawValue: relativeString)
            else { return nil }
            self.init(yomi: yomi, relative: relative)
        }

        func encode() -> [String: Any] {
            return [
                "yomi": yomi,
                "relative": relative.rawValue,
            ]
        }

        var timeInterval: TimeInterval {
            switch relative {
            case .now:
                return 0
            case .yesterday:
                return -24 * 60 * 60
            case .tomorrow:
                return 24 * 60 * 60
            }
        }
    }
}

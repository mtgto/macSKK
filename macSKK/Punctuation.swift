// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

/**
 * カンマとピリオドを入力したときに入力される句読点の設定．
 * ローマ字かな変換ルールを上書きすることが可能。
 */
struct Punctuation {
    enum Comma: Int, CaseIterable, Identifiable {
        typealias ID = Int
        var id: ID { rawValue }
        /// ローマ字かな変換ルールをそのまま適用する
        case `default` = 0
        /// "、" を入力する
        case ten = 1
        /// "，" (全角カンマ) を入力する
        case comma = 2

        init?(rawValue: Int) {
            switch rawValue & 3 {
            case 0:
                self = .default
            case 1:
                self = .ten
            case 2:
                self = .comma
            default:
                return nil
            }
        }

        var description: String {
            switch self {
            case .default:
                return String(localized: "Follow Romaji-Kana Rule")
            case .ten:
                return String(format: String(localized: "EnterKey"), "、")
            case .comma:
                return String(format: String(localized: "EnterKey"), "，")
            }
        }
    }

    enum Period: Int, CaseIterable, Identifiable {
        typealias ID = Int
        var id: ID { rawValue }
        /// ローマ字かな変換ルールをそのまま適用する
        case `default` = 0
        /// "。" を入力する
        case maru = 256
        /// "．" (全角ピリオド) を入力する
        case period = 512

        init?(rawValue: Int) {
            switch rawValue & 768 {
            case 0:
                self = .default
            case 256:
                self = .maru
            case 512:
                self = .period
            default:
                return nil
            }
        }

        var description: String {
            switch self {
            case .default:
                return String(localized: "Follow Romaji-Kana Rule")
            case .maru:
                return String(format: String(localized: "EnterKey"), "。")
            case .period:
                return String(format: String(localized: "EnterKey"), "．")
            }
        }
    }

    let comma: Comma
    let period: Period

    static let `default`: Self = .init(comma: .default, period: .default)

    init(comma: Punctuation.Comma, period: Punctuation.Period) {
        self.comma = comma
        self.period = period
    }

    init?(rawValue: Int) {
        guard let comma = Comma(rawValue: rawValue), let period = Period(rawValue: rawValue) else {
            return nil
        }
        self.comma = comma
        self.period = period
    }

    var rawValue: Int {
        comma.rawValue | period.rawValue
    }
}

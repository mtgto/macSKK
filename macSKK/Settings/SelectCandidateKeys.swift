// SPDX-License-Identifier: GPL-3.0-or-later

/// 変換候補の選択に使うキーの文字列のバリデーション
enum SelectCandidateKeys {
    /// 選択キーの文字数。候補パネルに一度に表示できる最大の候補数と同じ
    static let count = 9
    static let `default` = "123456789"
    /// 設定画面で選べるプリセット
    static let presets = ["123456789", "ASDFGHJKL", "AOEUIDHTN"]

    enum ValidationError: Error, Equatable {
        /// 文字数が ``SelectCandidateKeys/count`` ではない。値は入力された文字数
        case invalidLength(Int)
        /// 重複している文字がある (大文字小文字は区別しない)。値は重複している文字を大文字にしたもの
        case duplicated([Character])
        /// スペースを除く表示可能なASCII文字以外が含まれている。値は使えない文字
        case invalidCharacters([Character])
    }

    /**
     * 選択キーとして正しいかを検証し、大文字にそろえた文字列を返す。
     *
     * 複数の誤りがある場合は、使えない文字、重複、文字数の順で一つだけ報告する。
     * Shiftが必要な記号やキーバインドに割り当てられたキーは候補の選択に使えないが、
     * キーバインドは後から変更されうるのでここではエラーにしない。
     */
    static func validate(_ keys: String) throws(ValidationError) -> String {
        let invalidCharacters = unique(keys.filter { !isAllowed($0) })
        if !invalidCharacters.isEmpty {
            throw .invalidCharacters(invalidCharacters)
        }
        let uppercased = keys.uppercased()
        var seen = Set<Character>()
        let duplicated = unique(uppercased.filter { !seen.insert($0).inserted })
        if !duplicated.isEmpty {
            throw .duplicated(duplicated)
        }
        if uppercased.count != count {
            throw .invalidLength(uppercased.count)
        }
        return uppercased
    }

    /// 保存されていた値や同期で受け取った値を検証し、不正ならデフォルト値を返す
    static func sanitize(_ keys: String?) -> String {
        guard let keys, let validated = try? validate(keys) else {
            return Self.default
        }
        return validated
    }

    /// スペースを除く表示可能なASCII文字 ("!" から "~") か
    private static func isAllowed(_ character: Character) -> Bool {
        guard let asciiValue = character.asciiValue else { return false }
        // "\r\n" は asciiValue が "\n" になるが範囲外なので弾かれる
        return (0x21...0x7E).contains(asciiValue)
    }

    /// 出現順を保ったまま重複を除く
    private static func unique(_ characters: String) -> [Character] {
        var seen = Set<Character>()
        return characters.filter { seen.insert($0).inserted }
    }
}

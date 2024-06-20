// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

struct KeyBindingSet: Identifiable, Hashable {
    /// 設定の名称。
    let id: String
    static let defaultId: ID = "default"
    /**
     * 修飾キーを除いたキー入力が同じ場合は修飾キーが多いものが前に来るように並べた配列。
     * 入力に一番合致するキー入力を返すために最初にソートしてもっておく。
     */
    let sorted: [(KeyBinding.Input, KeyBinding.Action)]

    static let defaultKeyBindingSet = KeyBindingSet(id: Self.defaultId, values: KeyBinding.defaultKeyBindingSettings)

    init(id: String, values: [KeyBinding]) {
        self.id = id
        sorted = values.flatMap { keyValue in
            keyValue.inputs.map { ($0, keyValue.action) }
        }.sorted(by: { lts, rts in
            if lts.0.key == rts.0.key {
                return lts.0.modifierFlags.rawValue > rts.0.modifierFlags.rawValue
            } else {
                switch (lts.0.key, rts.0.key) {
                case let (.character(l), .character(r)):
                    return l < r
                case let (.code(l), .code(r)):
                    return l < r
                // .character, .codeはどういう順序で並んでいてもいいので、いったん`.code < .character`としておく。
                case (.character, .code):
                    return false
                case (.code, .character):
                    return true
                }
            }
        })
    }

    private init(id: String, sorted: [(KeyBinding.Input, KeyBinding.Action)]) {
        self.id = id
        self.sorted = sorted
    }

    func action(event: NSEvent) -> KeyBinding.Action? {
        sorted.first(where: { $0.0.accepts(event: event) })?.1
    }

    var canDelete: Bool {
        id != Self.defaultId
    }

    func copy(id: String) -> Self {
        return Self(id: id, sorted: sorted)
    }

    // MARK: Hashable
    static func == (lhs: KeyBindingSet, rhs: KeyBindingSet) -> Bool {
        return lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

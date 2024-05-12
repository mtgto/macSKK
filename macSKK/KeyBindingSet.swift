// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit

struct KeyBindingSet {
    let values: [KeyBinding.Action: [KeyBinding.Input]]
    let dict: [KeyBinding.Input: KeyBinding.Action]

    static let defaultKeyBindingSet = KeyBindingSet(KeyBinding.defaultKeyBindingSettings)

    init(_ values: [KeyBinding]) {
        self.values = Dictionary(uniqueKeysWithValues: values.map { ($0.action, $0.inputs) })
        self.dict = Dictionary(uniqueKeysWithValues: values.flatMap { keyValue in
            keyValue.inputs.map { ($0, keyValue.action) }
        })
    }

    func action(event: NSEvent) -> KeyBinding.Action? {
        return dict[KeyBinding.Input(event: event)]
    }
}

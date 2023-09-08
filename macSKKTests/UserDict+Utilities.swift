// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import macSKK

extension UserDict {
    func setEntries(_ entries: [String: [Word]]) {
        if let dict = dict as? FileDict {
            dict.setEntries(entries)
        }
    }

    func entries() -> [String: [Word]]? {
        if let dict = dict as? FileDict {
            return dict.dict.entries
        }
        return nil
    }
}

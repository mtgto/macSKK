// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

@testable import macSKK

extension UserDict {
    func setEntries(_ entries: [String: [Word]]) {
        if case .success(let userDict) = userDict, let dict = userDict as? FileDict {
            dict.setEntries(entries, readonly: true)
        }
    }

    func entries() -> [String: [Word]]? {
        if case .success(let userDict) = userDict, let dict = userDict as? FileDict {
            return dict.dict.entries
        }
        return nil
    }
}

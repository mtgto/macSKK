// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os

@testable import macSKK

/**
 * skkservへの問い合わせはCompletionPresenterの@concurrentな検索処理などから
 * MainActor外で行われるため、問い合わせ回数はロックで保護する。
 * 本来はMutex (SE-0433) を使いたいがmacOS 15以降のためデプロイメントターゲット13.3では使えない。
 */
final class MockSKKServDict: SKKServDictProtocol {
    /// skkservへの問い合わせ回数
    struct CallCount {
        var refer = 0
        var findCompletions = 0
    }

    let saveToUserDict = false
    let wordsPerYomi: [String: [Word]]
    let shouldFail: Bool
    private let callCount = OSAllocatedUnfairLock(initialState: CallCount())

    var referCallCount: Int { callCount.withLock { $0.refer } }
    var findCompletionsCallCount: Int { callCount.withLock { $0.findCompletions } }

    init(wordsPerYomi: [String: [Word]], shouldFail: Bool = false) {
        self.wordsPerYomi = wordsPerYomi
        self.shouldFail = shouldFail
    }

    func refer(_ yomi: String, option: DictReferringOption?) -> Result<[Word], any Error> {
        callCount.withLock { $0.refer += 1 }
        if shouldFail {
            return .failure(NSError(domain: "MockSKKServDict", code: 0))
        }
        return .success(wordsPerYomi[yomi] ?? [])
    }

    func findCompletions(prefix: String) -> Result<[String], any Error> {
        callCount.withLock { $0.findCompletions += 1 }
        if shouldFail {
            return .failure(NSError(domain: "MockSKKServDict", code: 0))
        }
        return .success(wordsPerYomi.keys.filter { $0.hasPrefix(prefix) && $0 != prefix }.sorted())
    }

    func invalidate() {}
}

extension UserDict {
    func setEntries(_ entries: [String: [Word]]) {
        if let dict = userDict as? FileDict {
            dict.setEntries(entries, readonly: true)
        }
    }

    func entries() -> [String: [Word]]? {
        if let dict = userDict as? FileDict {
            return dict.dict.entries
        }
        return nil
    }
}

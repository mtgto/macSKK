// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension UserDict {
    /// バックグラウンドスレッドからの辞書検索用スナップショット。
    /// MemoryDictはstruct+SendableかつCOWのため、値コピーのコストはほぼゼロ。
    struct Snapshot: Sendable {
        let userDictSnapshot: MemoryDict?
        let dictSnapshots: [MemoryDict]
        let dateYomis: [DateConversion.Yomi]
        let dateConversions: [DateConversion]
        let privateMode: Bool
        let ignoreUserDictInPrivateMode: Bool

        nonisolated func refer(_ yomi: String, option: DictReferringOption? = nil) -> [Word] {
            guard let userDictSnapshot else { return [] }
            if privateMode && ignoreUserDictInPrivateMode { return [] }
            return userDictSnapshot.refer(yomi, option: option)
        }

        nonisolated func referDicts(_ yomi: String, option: DictReferringOption?, findFromAllDicts: Bool) -> [Candidate] {
            var result: [Candidate] = []
            // ユーザー辞書、それ以外の辞書の順に参照する
            var candidates = refer(yomi, option: option).map { word in
                Candidate(word: word, saveToUserDict: true)
            }
            if let dateConversionYomi = dateYomis.first(where: { $0.yomi == yomi }) {
                let date = Date(timeIntervalSinceNow: dateConversionYomi.timeInterval)
                let dateCandidates = dateConversions.compactMap { conversion -> Candidate? in
                    guard let word = conversion.dateFormatter.string(for: date) else { return nil }
                    return Candidate(word, saveToUserDict: false)
                }
                candidates.append(contentsOf: dateCandidates)
            }
            if findFromAllDicts {
                dictSnapshots.forEach { dict in
                    candidates.append(contentsOf: dict.refer(yomi, option: option).map {
                        Candidate(word: $0, saveToUserDict: dict.saveToUserDict)
                    })
                }
            }
            if candidates.isEmpty {
                if let numberYomi = NumberYomi(yomi) {
                    let midashi = numberYomi.toMidashiString()
                    candidates = refer(midashi, option: nil).compactMap { word in
                        guard let numberCandidate = try? NumberCandidate(yomi: word.word) else { return nil }
                        guard let convertedWord = numberCandidate.toString(yomi: numberYomi) else { return nil }
                        let annotations: [Annotation] = if let annotation = word.annotation { [annotation] } else { [] }
                        return Candidate(convertedWord,
                                         annotations: annotations,
                                         original: Candidate.Original(midashi: midashi, word: word.word),
                                         saveToUserDict: true)
                    }
                    if findFromAllDicts {
                        dictSnapshots.forEach { dict in
                            candidates.append(contentsOf: dict.refer(midashi, option: nil).compactMap { word in
                                guard let numberCandidate = try? NumberCandidate(yomi: word.word) else { return nil }
                                guard let convertedWord = numberCandidate.toString(yomi: numberYomi) else { return nil }
                                let annotations: [Annotation] = if let annotation = word.annotation { [annotation] } else { [] }
                                return Candidate(convertedWord,
                                                 annotations: annotations,
                                                 original: Candidate.Original(midashi: midashi, word: word.word),
                                                 saveToUserDict: dict.saveToUserDict)
                            })
                        }
                    }
                }
            }
            for candidate in candidates {
                if let index = result.firstIndex(where: { $0.word == candidate.word }) {
                    do {
                        result[index] = try result[index].merge(candidate)
                    } catch {
                        logger.error("異なる変換結果をもつ変換候補同士をマージしようとしました。バグと思われます。")
                    }
                } else {
                    result.append(candidate)
                }
            }
            return result
        }

        nonisolated func findCompletionsDicts(prefix: String, findFromAllDicts: Bool) -> [String] {
            if prefix.isEmpty { return [] }
            var results: [String] = []
            var seen = Set<String>()
            if !privateMode || !ignoreUserDictInPrivateMode {
                if let userDictSnapshot {
                    for yomi in userDictSnapshot.findCompletions(prefix: prefix) {
                        if seen.insert(yomi).inserted { results.append(yomi) }
                    }
                }
            }
            dateYomis.forEach { dateYomi in
                if dateYomi.yomi.hasPrefix(prefix) && seen.insert(dateYomi.yomi).inserted {
                    results.append(dateYomi.yomi)
                }
            }
            if findFromAllDicts {
                for dict in dictSnapshots {
                    for yomi in dict.findCompletions(prefix: prefix) {
                        if seen.insert(yomi).inserted { results.append(yomi) }
                    }
                }
            }
            return results
        }

        nonisolated func candidatesForCompletion(prefix: String, findFromAllDicts: Bool) -> [Candidate] {
            if prefix.count == 1 {
                return referDicts(prefix, option: nil, findFromAllDicts: findFromAllDicts)
                    .map { candidate in
                        candidate.withOriginal(Candidate.Original(midashi: prefix, word: candidate.word))
                    }
            }
            var results: [Candidate] = []
            for midashi in findCompletionsDicts(prefix: prefix, findFromAllDicts: findFromAllDicts) {
                if results.count >= 100 { break }
                let candidates = referDicts(midashi, option: nil, findFromAllDicts: findFromAllDicts)
                    .prefix(100 - results.count)
                    .map { candidate in
                        candidate.withOriginal(Candidate.Original(midashi: midashi, word: candidate.word))
                    }
                results.append(contentsOf: candidates)
            }
            return results
        }
    }
}

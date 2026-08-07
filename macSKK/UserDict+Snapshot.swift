// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

extension UserDict {
    /// バックグラウンドスレッドからの辞書検索用スナップショット。
    /// MemoryDictはstruct+SendableかつCOWのため、値コピーのコストはほぼゼロ。
    struct Snapshot: Sendable {
        let userDict: MemoryDict?
        let dicts: [MemoryDict]
        let dateYomis: [DateConversion.Yomi]
        let dateConversions: [DateConversion]
        let privateMode: Bool
        let ignoreUserDictInPrivateMode: Bool

        nonisolated func refer(_ yomi: String, option: DictReferringOption? = nil) -> [Word] {
            guard let userDict else { return [] }
            if privateMode && ignoreUserDictInPrivateMode { return [] }
            return userDict.refer(yomi, option: option)
        }

        /// ローカル辞書 (ユーザー辞書・日付変換・ファイル辞書) から変換候補を検索する。
        /// 数値変換のフォールバックと注釈のマージは行わない。
        nonisolated private func localCandidates(_ yomi: String, option: DictReferringOption?, findFromAllDicts: Bool) -> [Candidate] {
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
                dicts.forEach { dict in
                    candidates.append(contentsOf: dict.refer(yomi, option: option).map {
                        Candidate(word: $0, saveToUserDict: dict.saveToUserDict)
                    })
                }
            }
            return candidates
        }

        /// 数値変換のフォールバックの結果。
        /// skkservへの問い合わせ結果を同じ見出しで数値変換するために numberYomi と midashi も保持する。
        private struct NumberFallback {
            let numberYomi: NumberYomi
            /// 数値を "#" に置換した見出し
            let midashi: String
            /// ローカル辞書から見つかった変換候補
            let candidates: [Candidate]
        }

        /// yomiが数値を含む場合に、数値を "#" に置換した見出しでローカル辞書を引く。
        /// yomiが数値を含まない場合はnilを返す。
        /// optionは通常の検索と同じものを渡す (接頭辞・接尾辞から検索する場合は数値変換の見出しも同じ扱いで引く)。
        nonisolated private func numberFallback(_ yomi: String, option: DictReferringOption?, findFromAllDicts: Bool) -> NumberFallback? {
            guard let numberYomi = NumberYomi(yomi) else { return nil }
            let midashi = numberYomi.toMidashiString()
            var candidates = Self.numberCandidates(from: refer(midashi, option: option),
                                                   numberYomi: numberYomi,
                                                   midashi: midashi,
                                                   saveToUserDict: true)
            if findFromAllDicts {
                dicts.forEach { dict in
                    candidates.append(contentsOf: Self.numberCandidates(from: dict.refer(midashi, option: option),
                                                                        numberYomi: numberYomi,
                                                                        midashi: midashi,
                                                                        saveToUserDict: dict.saveToUserDict))
                }
            }
            return NumberFallback(numberYomi: numberYomi, midashi: midashi, candidates: candidates)
        }

        /// 数値変換の変換候補を組み立てる。数値変換できない候補は除外する。
        nonisolated private static func numberCandidates(from words: [Word],
                                                         numberYomi: NumberYomi,
                                                         midashi: String,
                                                         saveToUserDict: Bool) -> [Candidate] {
            words.compactMap { word in
                guard let numberCandidate = try? NumberCandidate(yomi: word.word) else { return nil }
                guard let convertedWord = numberCandidate.toString(yomi: numberYomi) else { return nil }
                let annotations: [Annotation] = if let annotation = word.annotation { [annotation] } else { [] }
                return Candidate(convertedWord,
                                 annotations: annotations,
                                 original: Candidate.Original(midashi: midashi, word: word.word),
                                 saveToUserDict: saveToUserDict)
            }
        }

        /// ローカル辞書のみを引き変換候補順に返す。
        /// 複数の辞書に同じ変換がある場合、注釈を結合して返す。
        nonisolated func referDicts(_ yomi: String, option: DictReferringOption?, findFromAllDicts: Bool) -> [Candidate] {
            var candidates = localCandidates(yomi, option: option, findFromAllDicts: findFromAllDicts)
            if candidates.isEmpty, let fallback = numberFallback(yomi, option: option, findFromAllDicts: findFromAllDicts) {
                candidates = fallback.candidates
            }
            // 複数の辞書に同じ変換候補があれば注釈をマージして1つにまとめる
            return Self.mergeCandidates([], appending: candidates)
        }

        nonisolated func findCompletionsDicts(prefix: String, findFromAllDicts: Bool) -> [String] {
            if prefix.isEmpty { return [] }
            var results: [String] = []
            var seen = Set<String>()
            if !privateMode || !ignoreUserDictInPrivateMode {
                if let userDict {
                    for yomi in userDict.findCompletions(prefix: prefix) {
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
                for dict in dicts {
                    for yomi in dict.findCompletions(prefix: prefix) {
                        if seen.insert(yomi).inserted { results.append(yomi) }
                    }
                }
            }
            return results
        }

        /// 現在入力中のprefixに続く変換候補を検索する。
        /// prefixが1文字のときは完全一致だけを、2文字以上のときは見つかったものから最大100件までを返す。
        ///
        /// - Returns: 変換候補と、skkservへ変換候補を問い合わせるための見出し語のリスト。
        ///   見出し語は ``skkservCandidatesForCompletion(prefix:midashis:skkservDict:referLimit:)`` に渡す想定。
        ///   prefixが1文字のときは辞書に存在するかによらずprefix自身の1件、2文字以上のときは
        ///   ローカル辞書から見つかった見出し語を全件返す (変換候補の100件上限にかからなかったものも含む)。
        nonisolated func candidatesForCompletion(prefix: String, findFromAllDicts: Bool) -> (candidates: [Candidate], midashis: [String]) {
            if prefix.count == 1 {
                let candidates = referDicts(prefix, option: nil, findFromAllDicts: findFromAllDicts)
                    .map { candidate in
                        candidate.withOriginal(Candidate.Original(midashi: prefix, word: candidate.word))
                    }
                return (candidates, [prefix])
            }
            let midashis = findCompletionsDicts(prefix: prefix, findFromAllDicts: findFromAllDicts)
            var results: [Candidate] = []
            for midashi in midashis {
                if results.count >= 100 { break }
                let candidates = referDicts(midashi, option: nil, findFromAllDicts: findFromAllDicts)
                    .prefix(100 - results.count)
                    .map { candidate in
                        candidate.withOriginal(Candidate.Original(midashi: midashi, word: candidate.word))
                    }
                results.append(contentsOf: candidates)
            }
            return (results, midashis)
        }

        /**
         * skkservから補完候補となる変換候補を検索する。
         *
         * skkservへの問い合わせはTCP経由でオンメモリの辞書より桁違いに遅いため、
         * ローカル辞書の検索結果 (``candidatesForCompletion(prefix:findFromAllDicts:)``) を
         * 表示したあとに呼び出して結果を追記する用途を想定している。
         *
         * まずskkservから見出し語の補完を検索し、ローカル辞書から見つかった見出し語 (midashis) の
         * 末尾に重複を除いて追記する。そのうえで先頭referLimit件の見出し語について変換候補を問い合わせる。
         * prefixが1文字のときは ``candidatesForCompletion(prefix:findFromAllDicts:)`` と同じ規則で
         * 完全一致だけを対象とし、skkservからの見出し語の補完は行わない。
         * 問い合わせに失敗した場合は接続レベルのエラーの可能性が高いため以降の問い合わせは打ち切る。
         * タスクがキャンセルされた場合も以降の問い合わせを打ち切る (それまでの成否は返す)。
         *
         * - Parameters:
         *   - prefix: SKK辞書の見出しの接頭辞。 ``candidatesForCompletion(prefix:findFromAllDicts:)`` に渡したものと同じ文字列
         *   - midashis: ``candidatesForCompletion(prefix:findFromAllDicts:)`` が返した見出し語リスト
         *   - skkservDict: SKKServ辞書
         *   - referLimit: skkservへのreferの問い合わせの上限回数
         * - Returns: skkservから見つかった変換候補と、skkservへの問い合わせごとの成否。
         *   成否はエラーカウント処理のためMainActor上で ``UserDict/handleSKKServResults(_:)`` に渡すこと。
         */
        nonisolated static func skkservCandidatesForCompletion(prefix: String, midashis: [String], skkservDict: any SKKServDictProtocol, referLimit: Int) -> (candidates: [Candidate], skkservResults: [Result<Void, any Error>]) {
            var candidates: [Candidate] = []
            var skkservResults: [Result<Void, any Error>] = []
            var midashis = midashis
            // 1文字のときは全探索するとめちゃくちゃ量が多いので完全一致だけ探す
            if prefix.count > 1 {
                // 新しい読みの入力などで検索がキャンセルされたら残りの問い合わせは無駄なので打ち切る
                if Task.isCancelled {
                    return (candidates, skkservResults)
                }
                switch skkservDict.findCompletions(prefix: prefix) {
                case .success(let yomis):
                    skkservResults.append(.success(()))
                    midashis = mergeYomis(midashis, appending: yomis)
                case .failure(let error):
                    // 接続レベルのエラーの可能性が高いため以降の問い合わせは打ち切る
                    skkservResults.append(.failure(error))
                    return (candidates, skkservResults)
                }
            }
            for midashi in midashis.prefix(referLimit) {
                // 新しい読みの入力などで検索がキャンセルされたら残りの問い合わせは無駄なので打ち切る
                if Task.isCancelled {
                    return (candidates, skkservResults)
                }
                switch skkservDict.refer(midashi, option: nil) {
                case .success(let words):
                    skkservResults.append(.success(()))
                    candidates.append(contentsOf: words.map { word in
                        Candidate(word: word,
                                  original: Candidate.Original(midashi: midashi, word: word.word),
                                  saveToUserDict: skkservDict.saveToUserDict)
                    })
                case .failure(let error):
                    // 接続レベルのエラーの可能性が高いため以降の問い合わせは打ち切る
                    skkservResults.append(.failure(error))
                    return (candidates, skkservResults)
                }
            }
            return (candidates, skkservResults)
        }

        /// 補完候補の読みのリストに新しい読みを追加したリストを返す。
        /// 表示中の読みの選択位置が無効にならないように既存の読みの順序は保持し、新規の読みは末尾に追記する。
        nonisolated static func mergeYomis(_ yomis: [String], appending newYomis: [String]) -> [String] {
            var seen = Set(yomis)
            return yomis + newYomis.filter { seen.insert($0).inserted }
        }

        /// 変換候補のリストに新しい変換候補を追加したリストを返す。
        /// 同じ変換結果をもつ候補は注釈を結合し、新規の候補は末尾に追記する。
        nonisolated static func mergeCandidates(_ candidates: [Candidate], appending newCandidates: [Candidate]) -> [Candidate] {
            var result = candidates
            for candidate in newCandidates {
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
    }
}

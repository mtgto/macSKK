// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import XCTest

@testable import macSKK

// ReadonlyMemoryDict(読み込み専用辞書) のロード時のメモリ使用量を計測するテスト。
//
// 通常のテスト実行ではスキップされる。計測したいときだけ次のようにして実行すること。
//
// 実行方法:
//   1. 環境変数 `MACSKK_MEMORY_TEST=1` を設定する。
//      xcodebuild なら TEST_RUNNER_ プレフィックス付きで渡す:
//        TEST_RUNNER_MACSKK_MEMORY_TEST=1 xcodebuild test -scheme macSKK -destination 'platform=macOS' \
//          -only-testing:macSKKTests/ReadonlyMemoryDictMemoryTests/testLoadSKKJisyoL -resultBundlePath out.xcresult
//      結果は `xcrun xcresulttool export attachments --path out.xcresult --output-path <dir>` で取り出せる。
//      Xcodeなら Product > Scheme > Edit Scheme > Test > Arguments > Environment Variables に追加する。
//   2. 辞書ファイル SKK-JISYO.L (EUC-JIS-2004) を
//      `FileManager.default.temporaryDirectory/macSKKTests/SKK-JISYO.L` に置く。
//      サンドボックス下のテストでは通常
//      `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/tmp/macSKKTests/SKK-JISYO.L`
//   3. このテストクラスだけを単体で実行する。peakResidentBytes (ru_maxrss) はプロセス内の累積最大値なので、
//      他のテストと一緒に走らせると正しい値にならない。
//
// 結果の読み方:
//   - コンソールログの `MEMORY_METRIC key=value` 行
//   - テスト結果に添付される JSON (memory-metrics.json, XCTAttachment .keepAlways)
//   heapDeltaBytes のみ上限をassertしており、他の指標は表示のみ。

class ReadonlyMemoryDictMemoryTests: XCTestCase {
    /// 全mallocゾーンの使用中バイト数の合計
    private func heapInUse() -> Int {
        var total = 0
        var zones: UnsafeMutablePointer<vm_address_t>?
        var count: UInt32 = 0
        malloc_get_all_zones(mach_task_self_, nil, &zones, &count)
        guard let zones else { return 0 }
        for i in 0..<Int(count) {
            guard let zone = UnsafeMutablePointer<malloc_zone_t>(bitPattern: UInt(zones[i])),
                let introspect = zone.pointee.introspect
            else { continue }
            var stats = malloc_statistics_t()
            introspect.pointee.statistics(zone, &stats)
            total += Int(stats.size_in_use)
        }
        return total
    }

    /// ru_maxrss (macOSではバイト単位)
    private func peakResidentSize() -> Int {
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        return usage.ru_maxrss
    }

    /// heapDeltaBytes の上限。実測は約30.2MBでその約1.3倍に余裕を持たせている。
    /// 分割前のDictionary表現は約43.2MBなので、この上限ならDictionary表現への回帰を検知できる。
    private static let heapDeltaBytesUpperBound = 40_000_000

    func testLoadSKKJisyoL() throws {
        guard ProcessInfo.processInfo.environment["MACSKK_MEMORY_TEST"] == "1" else {
            throw XCTSkip("環境変数 MACSKK_MEMORY_TEST=1 を指定したときだけ実行します (xcodebuild なら TEST_RUNNER_MACSKK_MEMORY_TEST=1)。詳細はこのファイルの冒頭コメントを参照")
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("macSKKTests/SKK-JISYO.L")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(url.path) に SKK-JISYO.L を置いてください")
        }
        let source = try Data(contentsOf: url).eucJis2004String()
        let before = heapInUse()
        let clock = ContinuousClock()
        var dict: ReadonlyMemoryDict?
        let elapsed = clock.measure {
            dict = ReadonlyMemoryDict(dictId: "SKK-JISYO.L", source: source)
        }
        let heapDeltaBytes = heapInUse() - before
        withExtendedLifetime(source) {}
        try withExtendedLifetime(dict) {
            let loaded = try XCTUnwrap(dict)
            let entryCount = loaded.entryCount
            let loadMillis = elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000
            let metrics: [String: Int64] = [
                "heapDeltaBytes": Int64(heapDeltaBytes),
                "entryCount": Int64(entryCount),
                "loadMillis": Int64(loadMillis),
                "peakResidentBytes": Int64(peakResidentSize()),
            ]
            for key in metrics.keys.sorted() {
                print("MEMORY_METRIC \(key)=\(metrics[key]!)")
            }
            let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: metrics, options: [.sortedKeys, .prettyPrinted]),
                                           uniformTypeIdentifier: "public.json")
            attachment.name = "memory-metrics.json"
            attachment.lifetime = .keepAlways
            add(attachment)
            XCTAssertLessThan(heapDeltaBytes, Self.heapDeltaBytesUpperBound)
        }
    }
}

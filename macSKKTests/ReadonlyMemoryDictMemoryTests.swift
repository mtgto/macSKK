// SPDX-License-Identifier: GPL-3.0-or-later

import Darwin
import XCTest

@testable import macSKK

/// MemoryDictのメモリ使用量を計測するテスト。
///
/// `FileManager.default.temporaryDirectory/macSKKTests/SKK-JISYO.L` が無ければスキップする。
/// peakResidentBytes (ru_maxrss) はプロセス内の累積最大値なので、このテスト単体で実行すること。
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

    func testLoadSKKJisyoL() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("macSKKTests/SKK-JISYO.L")
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw XCTSkip("\(url.path) がありません")
        }
        let source: String = {
            // swift-format-ignore
            let data = try! Data(contentsOf: url)
            return try! data.eucJis2004String()
        }()
        let before = heapInUse()
        let clock = ContinuousClock()
        var dict: MemoryDict?
        let elapsed = clock.measure {
            dict = MemoryDict(dictId: "SKK-JISYO.L", source: source, readonly: true)
        }
        let dictHeap = heapInUse()
        withExtendedLifetime(source) {}
        try withExtendedLifetime(dict) {
            let loaded = try XCTUnwrap(dict)
            let entryCount = loaded.entries.count
            let yomisBefore = heapInUse()
            var copied = loaded.okuriNashiYomis
            // COWによる配列バッファの複製を強制する (Stringの実体は共有される)
            copied.withUnsafeMutableBufferPointer { _ in }
            let yomisArrayBytes = heapInUse() - yomisBefore
            withExtendedLifetime(copied) {}
            let ms = elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000
            print("MEMORY_METRIC heapDeltaBytes=\(dictHeap - before)")
            print("MEMORY_METRIC entryCount=\(entryCount)")
            print("MEMORY_METRIC loadMillis=\(ms)")
            print("MEMORY_METRIC peakResidentBytes=\(peakResidentSize())")
            print("MEMORY_METRIC yomisArrayBytes=\(yomisArrayBytes)")
            XCTAssertGreaterThan(entryCount, 100_000)
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os
import XCTest

final class AsyncTimeoutTests: XCTestCase {
    func testWithTimeoutReturnsValueWhenOperationFinishesInTime() async throws {
        let result = try await withTimeout(seconds: 10.0) { "done" }
        XCTAssertEqual(result, "done")
    }

    func testWithTimeoutThrowsTimeoutError() async throws {
        do {
            _ = try await withTimeout(seconds: 0.01) {
                try await Task.sleep(for: .seconds(10))
                return "done"
            }
            XCTFail("TimeoutErrorが投げられる")
        } catch is TimeoutError {
            // 期待通り
        }
    }

    func testWithTimeoutCancelsOperationWhenTimedOut() async throws {
        // キャンセルハンドラ (@Sendableクロージャ) から書き込むためロックで保護する。
        // 本来はMutex (SE-0433) を使いたいがmacOS 15以降のためデプロイメントターゲット13.3では使えない。
        let cancelled = OSAllocatedUnfairLock(initialState: false)
        do {
            _ = try await withTimeout(seconds: 0.01) {
                await withTaskCancellationHandler {
                    try? await Task.sleep(for: .seconds(10))
                } onCancel: {
                    cancelled.withLock { $0 = true }
                }
                return "done"
            }
            XCTFail("TimeoutErrorが投げられる")
        } catch is TimeoutError {
            // 期待通り
        }
        // TaskGroupはキャンセルハンドラの実行を含めて子タスクの終了を待ってから抜ける
        XCTAssertTrue(cancelled.withLock { $0 }, "タイムアウト時はoperationがキャンセルされる")
    }

    func testWithTimeoutPropagatesCancellation() async throws {
        let task = Task {
            try await withTimeout(seconds: 10.0) {
                try await Task.sleep(for: .seconds(10))
                return "done"
            }
        }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("CancellationErrorが投げられる")
        } catch is CancellationError {
            // 期待通り。外側のキャンセルはタイムアウトとは区別する
        }
    }

    func testSingleResultContinuationResumeBeforeInstall() async throws {
        let continuation = SingleResultContinuation<String>()
        continuation.resume(with: .success("resumed"))
        let result = try await withCheckedThrowingContinuation { checked in
            continuation.install(checked)
        }
        XCTAssertEqual(result, "resumed")
    }

    func testSingleResultContinuationIgnoresSecondResume() async throws {
        let continuation = SingleResultContinuation<String>()
        // 二重resumeするとwithCheckedThrowingContinuationは実行時エラーになるため、
        // このテストが通ること自体が二重resumeを防げている証拠になる
        let result = try await withCheckedThrowingContinuation { (checked: CheckedContinuation<String, any Error>) in
            continuation.install(checked)
            continuation.resume(with: .success("first"))
            continuation.resume(with: .failure(CancellationError()))
        }
        XCTAssertEqual(result, "first")
    }
}

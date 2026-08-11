// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import os

/// ``withTimeout(seconds:operation:)`` で制限時間内に処理が完了しなかったことを表すエラー。
struct TimeoutError: Error, Equatable {}

/**
 * operationが制限時間内に完了しなければ ``TimeoutError`` を投げる。
 *
 * operationが先に完了した場合はタイマーを、タイムアウトした場合はoperationをキャンセルする。
 * 外側のタスクがキャンセルされた場合は ``TimeoutError`` ではなくCancellationErrorが投げられる。
 *
 * - NOTE: TaskGroupは子タスクの終了を待ってから抜けるため、operationはキャンセルに応じて
 *         必ず終了する必要がある。応答待ちのcontinuationを放置するとハングする。
 */
func withTimeout<T: Sendable>(seconds: TimeInterval,
                              operation: @escaping @Sendable () async throws -> T) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(for: .seconds(seconds))
            throw TimeoutError()
        }
        // 先に完了したほうの結果を採用し、残りの子タスクはキャンセルする
        defer { group.cancelAll() }
        return try await group.next()!
    }
}

/**
 * 最初に届いた結果だけを採用してCheckedContinuationを高々一度だけresumeするラッパー。
 *
 * コールバックベースのAPIをasyncに変換する際、応答とタイムアウト・キャンセルが同時に起きても
 * 二重resume (実行時エラーになる) を起こさないようにロックで保護する。
 * ``install(_:)`` より先に ``complete(with:)`` が呼ばれた場合は結果を保持しておき、install時に渡す。
 *
 * - NOTE: 同じ「最初の1つの結果だけを採用する」役割の同期版が、macSKKターゲットの
 *         `SingleResultWaiter` にある。あちらはセマフォでスレッドをブロックして待つ。
 * - NOTE: 本来はMutex (SE-0433) を使いたいがmacOS 15以降のためデプロイメントターゲット13.3では使えない。
 */
final class SingleResultContinuation<T: Sendable>: Sendable {
    private struct State {
        var continuation: CheckedContinuation<T, any Error>?
        /// installより先にcompleteされた場合の結果
        var pendingResult: Result<T, any Error>?
        var isFinished = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    /// continuationを登録する。すでに結果が確定していた場合はその結果で即座にresumeする。
    func install(_ continuation: CheckedContinuation<T, any Error>) {
        let pendingResult = state.withLock { state -> Result<T, any Error>? in
            guard let pendingResult = state.pendingResult else {
                state.continuation = continuation
                return nil
            }
            state.pendingResult = nil
            return pendingResult
        }
        if let pendingResult {
            continuation.resume(with: pendingResult)
        }
    }

    /// 結果を確定させる。continuationが登録済みならその場でresumeする。2回目以降の呼び出しは無視する。
    func complete(with result: Result<T, any Error>) {
        let continuation = state.withLock { state -> CheckedContinuation<T, any Error>? in
            guard !state.isFinished else { return nil }
            state.isFinished = true
            guard let continuation = state.continuation else {
                state.pendingResult = result
                return nil
            }
            state.continuation = nil
            return continuation
        }
        continuation?.resume(with: result)
    }

    /**
     * 結果が確定するまで待つ。待っている間にキャンセルされた場合はCancellationErrorを投げる。
     *
     * - NOTE: キャンセル時に結果を確定させないと ``withTimeout(seconds:operation:)`` が
     *         TaskGroupの子タスクの終了を待ってハングする。その配線をここに閉じ込めている。
     */
    func value() async throws -> T {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { self.install($0) }
        } onCancel: {
            self.complete(with: .failure(CancellationError()))
        }
    }
}

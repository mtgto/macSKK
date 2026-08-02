// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation

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
 * ``install(_:)`` より先に ``resume(with:)`` が呼ばれた場合は結果を保持しておき、install時に渡す。
 *
 * - NOTE: 同じ「最初の1つの結果だけを採用する」役割の同期版が、macSKKターゲットの
 *         `SingleResultWaiter` にある。あちらはセマフォでスレッドをブロックして待つ。
 *         ターゲットも待ち方も異なるため別の型にしている。
 */
final class SingleResultContinuation<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T, any Error>?
    /// installより先にresumeされた場合の結果
    private var pendingResult: Result<T, any Error>?
    private var isFinished = false

    /// continuationを登録する。すでにresumeされていた場合はその結果で即座にresumeする。
    func install(_ continuation: CheckedContinuation<T, any Error>) {
        lock.lock()
        if let pendingResult {
            self.pendingResult = nil
            lock.unlock()
            continuation.resume(with: pendingResult)
        } else {
            self.continuation = continuation
            lock.unlock()
        }
    }

    /**
     * 結果が確定するまで待つ。待っている間にキャンセルされた場合はCancellationErrorを投げる。
     *
     * - NOTE: キャンセル時にresumeしないと ``withTimeout(seconds:operation:)`` が
     *         TaskGroupの子タスクの終了を待ってハングする。その配線をここに閉じ込めている。
     */
    func value() async throws -> T {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { self.install($0) }
        } onCancel: {
            self.resume(with: .failure(CancellationError()))
        }
    }

    /// 結果を渡してcontinuationをresumeする。2回目以降の呼び出しは無視する。
    func resume(with result: Result<T, any Error>) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            return
        }
        isFinished = true
        if let continuation {
            self.continuation = nil
            lock.unlock()
            continuation.resume(with: result)
        } else {
            pendingResult = result
            lock.unlock()
        }
    }
}

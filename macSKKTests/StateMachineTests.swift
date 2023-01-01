// SPDX-FileCopyrightText: 2022 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Combine
import XCTest

@testable import macSKK

final class StateMachineTests: XCTestCase {
    let stateMachine = StateMachine(initialState: State(inputMode: .hiragana))
    var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        cancellables = []
    }

    func testHandleNormalSimple() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.sink { event in
            if case .fixedText("あ") = event {
                expectation.fulfill()
            } else {
                XCTFail(#"想定していた状態遷移が起きませんでした: "\#(event)""#)
            }
        }.store(in: &cancellables)
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .printable("a"), originalEvent: nil)))
        wait(for: [expectation], timeout: 1.0)
    }

    func testHandleNormalRomaji() throws {
        let expectation = XCTestExpectation()
        stateMachine.inputMethodEvent.collect(8).sink { events in
            XCTAssertEqual(events[0], .markedText("n"))
        }
        "ngabyn".forEach { char in
            XCTAssertTrue(stateMachine.handle(Action(keyEvent: .printable(String(char)), originalEvent: nil)))
        }
        XCTAssertTrue(stateMachine.handle(Action(keyEvent: .enter, originalEvent: nil)))
        wait(for: [expectation], timeout: 1.0)
    }

    //    func testHandle2() throws {
    //        let expectation = XCTestExpectation()
    //        stateMachine.inputMethodEvent.collect(8).sink { events in
    //            XCTAssertEqual(textEvents[0], .marked(MarkedText(prefix: "", text: "n")))
    //            XCTAssertEqual(textEvents[1], .fixed("ん"))
    //            XCTAssertEqual(textEvents[2], .marked(MarkedText(prefix: "", text: "g")))
    //            XCTAssertEqual(textEvents[3], .fixed("が"))
    //            XCTAssertEqual(textEvents[4], .marked(MarkedText(prefix: "", text: "b")))
    //            XCTAssertEqual(textEvents[5], .marked(MarkedText(prefix: "", text: "by")))
    //            XCTAssertEqual(textEvents[6], .marked(MarkedText(prefix: "", text: "n")), "子音が連続したら前の子音がキャンセルされる")
    //            XCTAssertEqual(textEvents[7], .fixed("ん"), "nが入力されているときにエンターされたら「ん」を確定する")
    //            expectation.fulfill()
    //        }
    //        XCTAssertTrue(stateMachine.handle(UserInput(eventType: .input(text: "n"))))
    //        XCTAssertTrue(stateMachine.handle(UserInput(eventType: .input(text: "g"))))
    //        XCTAssertTrue(stateMachine.handle(UserInput(eventType: .input(text: "a"))))
    //        XCTAssertTrue(stateMachine.handle(UserInput(eventType: .input(text: "b"))))
    //        XCTAssertTrue(stateMachine.handle(UserInput(eventType: .input(text: "y"))))
    //        XCTAssertTrue(stateMachine.handle(UserInput(eventType: .input(text: "n"))))
    //        XCTAssertTrue(stateMachine.handle(UserInput(eventType: .enter)))
    //        wait(for: [expectation], timeout: 1.0)
    //        XCTAssertNotNil(cancellable)
    //    }

    private func nextInputMethodEvent() async -> InputMethodEvent {
        var cancellation: Cancellable?
        let cancel = { cancellation?.cancel() }
        return await withTaskCancellationHandler {
            return await withCheckedContinuation { continuation in
                cancellation = stateMachine.inputMethodEvent.sink { event in
                    continuation.resume(with: .success(event))
                }
            }
        } onCancel: {
            cancel()
        }
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import Carbon.HIToolbox.Events
import Cocoa

extension NSEvent {
    static let charactersIgnoringModifiersMap: [UInt16: String] = [
        UInt16(kVK_ANSI_1): "1",
        UInt16(kVK_ANSI_2): "2",
        UInt16(kVK_ANSI_3): "3",
        UInt16(kVK_ANSI_4): "4",
        UInt16(kVK_ANSI_5): "5",
        UInt16(kVK_ANSI_6): "6",
        UInt16(kVK_ANSI_7): "7",
        UInt16(kVK_ANSI_8): "8",
        UInt16(kVK_ANSI_9): "9",
        UInt16(kVK_ANSI_0): "0",
        UInt16(kVK_ANSI_LeftBracket): "[",
        UInt16(kVK_ANSI_RightBracket): "]",
        UInt16(kVK_ANSI_Minus): "-",
        UInt16(kVK_ANSI_Equal): "=",
        UInt16(kVK_ANSI_Semicolon): ";",
        UInt16(kVK_ANSI_Comma): ",",
        UInt16(kVK_ANSI_Period): ".",
        UInt16(kVK_ANSI_Slash): "/",
        UInt16(kVK_ANSI_Backslash): "\\",
        UInt16(kVK_ANSI_Quote): "'",
    ]
    /**
     * キーイベントをIMKInputController.handleの入力イベント形式に変換する。
     *
     * IMKInputController.handleの引数のNSEventとkeyDownイベントで、
     * シフトが押されているときのNSEvent.charactersIgnoringModifiersの差異を吸収するために利用する。
     * 差異がない場合はそのまま返す。
     *
     * input | 非InputMethodKit | InputMethodKit
     * ----- | ---------------- | --------------
     * `Shift-a` | "A" | "a"
     * `Shift-.` | ">" | "."
     * `Option-Shift-.` | ">" | "."
     */
    func asInputMethodKitKeyEvent() -> NSEvent? {
        // キーイベント以外はなにもしない
        if type != .keyDown && type != .keyUp {
            return self
        }
        if modifierFlags.contains(.shift) {
            if let charactersIgnoringModifiers, let characters {
                if let converted = Self.charactersIgnoringModifiersMap[keyCode] {
                    return NSEvent.keyEvent(with: type,
                                            location: locationInWindow,
                                            modifierFlags: modifierFlags,
                                            timestamp: timestamp,
                                            windowNumber: windowNumber,
                                            context: nil,
                                            characters: characters,
                                            charactersIgnoringModifiers: converted,
                                            isARepeat: isARepeat,
                                            keyCode: keyCode)
                }
            }
            // TODO
            return self
        }
        return self
    }
}

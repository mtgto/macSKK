// SPDX-License-Identifier: GPL-3.0-or-later

import Carbon.HIToolbox.TextInputSources
import CoreServices
import Cocoa

extension NSEvent {
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
            if let characters, let converted = actualCharactersIgnoringModifiers {
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
        return self
    }

    /**
     * 修飾キーなしで現在のキー配列で入力したときの文字列を返す。
     * 例えばキー配列をDvorakに変えている場合、Qwerty配列でのSキーの位置を押した場合は "s" ではなく "o" を返す。
     */
    var actualCharactersIgnoringModifiers: String? {
        guard let inputSource = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return nil
        }

        let keyLayoutPtr = unsafeBitCast(CFDataGetBytePtr(unsafeBitCast(layoutData, to: CFData.self)),
                                         to: UnsafePointer<UCKeyboardLayout>.self)
        var deadKeyState: UInt32 = 0
        let maxStringLength = 4
        var actualStringLength = 0
        var unicodeString = [UniChar](repeating: 0, count: maxStringLength)

        let status = UCKeyTranslate(
            keyLayoutPtr,
            keyCode,
            UInt16(kUCKeyActionDown),
            0,
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            maxStringLength,
            &actualStringLength,
            &unicodeString
        )

        guard status == noErr else { return nil }

        return String(utf16CodeUnits: unicodeString, count: actualStringLength)
    }
}

// SPDX-License-Identifier: GPL-3.0-or-later

import AppKit
import CoreServices
import Carbon.HIToolbox.TextInputSources

extension NSEvent {
    /**
     * キーイベントについて、修飾キーが押されてないときの文字列を返す。
     * 例えば Shift-aなら "A" ではなく "a"、Shift-1なら "!" ではなく "1" を返す。
     * 正常に取得できなかった場合は`nil`を返す
     *
     * > NOTE: macOS 13では ``NSEvent/characters(byApplyingModifiers:)`` がnilを返す問題が発覚したため、
     *         そのような環境用にCoreServicesの古いAPIで取得している。
     */
    var charactersWithoutModifiers: String? {
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

        guard status == noErr else {
            logger.warning("入力されたキーの情報が取得できませんでした: status=\(status)")
            return nil
        }

        return String(utf16CodeUnits: unicodeString, count: actualStringLength)
    }
}

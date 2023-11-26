// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import InputMethodKit

/// キー配列
struct InputSource {
    // inputSourceID
    let id: String
    let localizedName: String

    // インストール済で利用可能なキー配列を取得する
    static func fetch() -> [InputSource]? {
        let dict: [CFString: AnyObject] = [
            kTISPropertyInputSourceType: kTISTypeKeyboardLayout,
            kTISPropertyInputSourceIsASCIICapable: kCFBooleanTrue,
        ]
        guard let result = TISCreateInputSourceList(dict as CFDictionary, true).takeUnretainedValue() as? Array<TISInputSource> else {
            return nil
        }
        return result.compactMap { inputSource -> InputSource? in
            guard let id = getStringProperty(inputSource, key: kTISPropertyInputSourceID) else { return nil }
            guard let localizedName = getStringProperty(inputSource, key: kTISPropertyLocalizedName) else { return nil }
            return InputSource(id: id, localizedName: localizedName)
        }
    }

    static func getStringProperty(_ tisInputSource: TISInputSource, key: NSString) -> String? {
        guard let pointer = TISGetInputSourceProperty(tisInputSource, key) else { return nil }
        return String(Unmanaged<NSString>.fromOpaque(pointer).takeUnretainedValue())
    }
}

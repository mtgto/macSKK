// SPDX-FileCopyrightText: 2023 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import InputMethodKit

/// キー配列
struct InputSource: Hashable, Identifiable {
    // inputSourceID
    let id: String
    let localizedName: String
    // 初期値はQWERTY
    static let defaultInputSourceId = "com.apple.keylayout.ABC"

    // インストール済で利用可能なキー配列を取得する
    static func fetch() -> [InputSource]? {
        let options: [CFString: AnyObject] = [
            kTISPropertyInputSourceType: kTISTypeKeyboardLayout,
            kTISPropertyInputSourceIsASCIICapable: kCFBooleanTrue,
        ]
        // APIドキュメントには特に書いてないけどCFGetRetainCountで見るとretainedな値を返してそうなのでtakeRetainedValueで変換
        guard let result = TISCreateInputSourceList(options as CFDictionary, true).takeRetainedValue() as? Array<TISInputSource> else {
            return nil
        }
        return result.compactMap { inputSource -> InputSource? in
            guard let id = getStringProperty(inputSource, key: kTISPropertyInputSourceID) else { return nil }
            guard let localizedName = getStringProperty(inputSource, key: kTISPropertyLocalizedName) else { return nil }
            // 第一言語が英語じゃないものは弾く。
            // APIドキュメントには特に書いてないけどCFGetRetainCountで見るとretainedな値を返してそうなのでtakeRetainedValueで変換
            if let languagesPointer = TISGetInputSourceProperty(inputSource, kTISPropertyInputSourceLanguages),
               let languages = Unmanaged<CFArray>.fromOpaque(languagesPointer).takeRetainedValue() as? Array<String> {
                if let first = languages.first {
                    if first != "en" {
                        return nil
                    }
                }
            }
            return InputSource(id: id, localizedName: localizedName)
        }
    }

    static func getStringProperty(_ tisInputSource: TISInputSource, key: NSString) -> String? {
        guard let pointer = TISGetInputSourceProperty(tisInputSource, key) else { return nil }
        return unsafeBitCast(pointer, to: CFString.self) as String
    }
}

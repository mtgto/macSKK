// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import InputMethodKit

/**
 * テスト用のIMKTextInput実装。クライアント (テキストを編集しているアプリ) を模倣する。
 *
 * 未確定文字列も実際のクライアントと同じくテキストの一部として持つので、
 * ``text`` には未確定文字列を含んだ文書全体が入る。
 */
final class MockTextInput: NSObject, IMKTextInput {
    /// クライアントが持っているテキスト。未確定文字列を含む
    private(set) var text: String
    /// キャレット位置 (UTF-16でのオフセット)。選択範囲は持たない
    private(set) var caret: Int
    /// setMarkedTextのreplacementRangeを解釈するかどうか。
    /// falseのときは範囲指定を無視するクライアントを模倣してキャレット位置に未確定文字列を置く
    let supportsMarkedTextReplacementRange: Bool
    /// selectedRangeでNSNotFoundを返すかどうか。カーソル位置を返さないクライアントを模倣する
    let supportsSelectedRange: Bool
    /// クライアントのBundle Identifier
    let clientBundleIdentifier: String
    /// 未確定文字列が占めている範囲。未確定文字列がないときはnil
    private(set) var markedTextRange: NSRange?
    /// 現在の未確定文字列
    var markedText: String {
        markedTextRange.map { (text as NSString).substring(with: $0) } ?? ""
    }

    init(text: String = "",
         supportsMarkedTextReplacementRange: Bool = true,
         supportsSelectedRange: Bool = true,
         bundleIdentifier: String = "net.mtgto.inputmethod.macSKKTests") {
        self.text = text
        self.caret = (text as NSString).length
        self.supportsMarkedTextReplacementRange = supportsMarkedTextReplacementRange
        self.supportsSelectedRange = supportsSelectedRange
        self.clientBundleIdentifier = bundleIdentifier
    }

    /// カーソルを移動する。確定直後でない状態を作るために使う
    func moveCaret(to location: Int) {
        caret = location
    }

    // MARK: - IMKTextInput
    func insertText(_ string: Any!, replacementRange: NSRange) {
        let inserted = (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
        let range: NSRange
        if let markedTextRange {
            // 未確定文字列があるときはそれを置き換えて確定する
            range = markedTextRange
        } else if replacementRange.location != NSNotFound {
            range = replacementRange
        } else {
            range = NSRange(location: caret, length: 0)
        }
        replaceCharacters(in: range, with: inserted)
        markedTextRange = nil
    }

    func insertText(_ string: Any!) {
        insertText(string, replacementRange: NSRange(location: NSNotFound, length: NSNotFound))
    }

    func setMarkedText(_ string: Any!, selectionRange: NSRange, replacementRange: NSRange) {
        let inserted = (string as? String) ?? (string as? NSAttributedString)?.string ?? ""
        let range: NSRange
        if let markedTextRange {
            // 未確定文字列があるときはそれを置き換える
            range = markedTextRange
        } else if supportsMarkedTextReplacementRange && replacementRange.location != NSNotFound {
            range = replacementRange
        } else {
            range = NSRange(location: caret, length: 0)
        }
        replaceCharacters(in: range, with: inserted)
        let length = (inserted as NSString).length
        markedTextRange = length > 0 ? NSRange(location: range.location, length: length) : nil
    }

    /// テキストの一部を置き換えてキャレットを置き換えた文字列の直後に移す
    private func replaceCharacters(in range: NSRange, with string: String) {
        let mutable = NSMutableString(string: text)
        mutable.replaceCharacters(in: range, with: string)
        text = mutable as String
        caret = range.location + (string as NSString).length
    }

    func selectedRange() -> NSRange {
        if supportsSelectedRange {
            return NSRange(location: caret, length: 0)
        } else {
            return NSRange(location: NSNotFound, length: NSNotFound)
        }
    }

    func markedRange() -> NSRange {
        markedTextRange ?? NSRange(location: NSNotFound, length: NSNotFound)
    }

    func attributedSubstring(from range: NSRange) -> NSAttributedString! {
        let nsText = text as NSString
        guard range.location != NSNotFound, range.location + range.length <= nsText.length else {
            return nil
        }
        return NSAttributedString(string: nsText.substring(with: range))
    }

    func length() -> Int {
        (text as NSString).length
    }

    func characterIndex(for point: NSPoint, tracking: IMKLocationToOffsetMappingMode, inMarkedRange: UnsafeMutablePointer<ObjCBool>!) -> Int {
        NSNotFound
    }

    func attributes(forCharacterIndex index: Int, lineHeightRectangle lineRect: UnsafeMutablePointer<NSRect>!) -> [AnyHashable: Any]! {
        [:]
    }

    func validAttributesForMarkedText() -> [Any]! {
        []
    }

    func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {}

    func selectMode(_ modeIdentifier: String!) {}

    func supportsUnicode() -> Bool { true }

    func bundleIdentifier() -> String! { clientBundleIdentifier }

    func windowLevel() -> CGWindowLevel { 0 }

    func supportsProperty(_ property: TSMDocumentPropertyTag) -> Bool { false }

    func uniqueClientIdentifierString() -> String! { "macSKKTests" }

    func string(from range: NSRange, actualRange: NSRangePointer!) -> String! {
        attributedSubstring(from: range)?.string
    }

    func firstRect(forCharacterRange aRange: NSRange, actualRange: NSRangePointer!) -> NSRect {
        .zero
    }
}

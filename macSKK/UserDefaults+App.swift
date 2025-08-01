import Foundation

extension UserDefaults {
    // ユニットテスト実行時に本体アプリ設定と別にしておく
    static var app: UserDefaults {
        isTest() ? UserDefaults(suiteName: "net.mtgto.inputmethod.macSKK.test")! : .standard
    }
}

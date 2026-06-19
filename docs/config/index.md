# 設定の概要

macSKKが入力メソッドとして選択されているときに、**入力メニュー → 設定…** でGUI設定画面を開けます。

設定はPlist形式で以下に保存されます。

```
~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Library/Preferences/net.mtgto.inputmethod.macSKK.plist
```

## 設定画面の構成

| 画面 | 主な内容 |
|---|---|
| [一般](./general) | Enterキー動作・キー配列・候補表示・句読点・入力モード表示 |
| [辞書](./dictionary) | 辞書ファイルの管理・SKKServ・ユーザー辞書 |
| [変換候補パネル](./candidate-window) | 変換候補と注釈のフォント・背景色 |
| [日付変換](./date-conversion) | 日付変換の読みとフォーマット |
| [補完](./completion) | 読み補完・変換候補補完の動作設定 |
| [キーバインド](./keybinding) | SKKのキーバインドのカスタマイズ |
| [ローマ字かな変換ルール](./kana-rule) | カスタムルールファイルの選択 |
| [ソフトウェアアップデート](./software-update) | バージョン確認・自動チェック |
| [直接入力](./direct-mode) | アプリごとにIME処理をバイパス |
| [互換性の設定](./workaround) | アプリ別の互換性ワークアラウンド |
| [ログ](./log) | アプリケーションログの表示 |
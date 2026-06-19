# アンインストール

現在、専用のアンインストーラーは用意していません (将来的にDMG内に同梱予定です)。手動で以下の手順を実行してください。

## 手順

1. **システム設定 → キーボード → 入力ソース** から「ひらがな」「ABC」を削除する
2. 以下のファイル・フォルダを削除する

| パス | 内容 |
|---|---|
| `/Library/Input Methods/macSKK.app` | アプリ本体 |
| `~/Library/Containers/net.mtgto.inputmethod.macSKK` | 辞書・設定・ユーザー辞書など |

::: warning
ユーザー辞書 (`~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/skk-jisyo.utf8`) を削除するとこれまで登録した単語がすべて失われます。必要であればバックアップを取っておいてください。
:::

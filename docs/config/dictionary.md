# 辞書

設定画面の「辞書」タブにある設定項目です。

## ユーザー辞書 {#user-dictionary}

変換・単語登録の結果が自動的に保存される辞書です。読み込み状態が表示されます。

保存先:

```
~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/skk-jisyo.utf8
```

テキストエディタで直接編集できます。別プロセスで更新された場合は自動で再読み込みされます。

即時保存したい場合は **入力メニュー → ユーザー辞書を今すぐ保存 / Save User Dictionary** を選択してください。

::: warning
`Command + Option + Esc` による強制終了やシグナルによる終了では未保存の内容が失われます。
:::

## SKKServ

skkservサーバーを辞書として使用できます（macSKKがskkservサーバーとして機能するわけではありません）。

::: warning ベータ機能
動作確認は [yaskkserv2](https://github.com/wachikun/yaskkserv2) でのみ行っています。
:::

有効/無効のトグルと、`i` ボタンから詳細設定シートを開けます。

| 項目 | 説明 |
|---|---|
| **アドレス / Address** | IPv4、IPv6、またはホスト名。例: `localhost`, `127.0.0.1`, `::1` |
| **TCPポート番号 / TCP Port** | 通常は `1178` |
| **応答エンコーディング / Response Encoding** | 通常はEUC-JP（実装によってはUTF-8） |
| **ユーザー辞書に変換履歴を保存する** | Google Japanese Inputなどを参照するskkservでユーザー辞書には保存したくない場合はオフにしてください |
| **補完候補を検索する** | 使用するskkservが補完検索に対応している場合のみ有効にしてください |
| **無効化に必要な連続エラーの回数 / The number of consecutive errors required to disable** | 連続してエラーになった場合に自動的にskkservの参照を無効化する回数 |

**現在の制限:**
- 同時に1サーバーまで
- TCP切断または1秒以内に送受信できなかった場合は取得失敗として扱う
- 変換候補はファイル辞書より後に表示される

## ファイル辞書 {#dictionary-files}

辞書フォルダに置いたSKK辞書ファイルが一覧表示されます。

辞書フォルダのパス:

```
~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries
```

[skk-dev/dict](https://github.com/skk-dev/dict) の `SKK-JISYO.L` がよく使われます。

### 対応フォーマット

| フォーマット | 対応状況 |
|---|---|
| SKK辞書形式 (EUC-JP) | ○ |
| SKK辞書形式 (UTF-8) | ○ |
| JSON形式 | ○ |
| YAML形式 | × |

上記の対応フォーマットはgzip圧縮された形式 (`.gz`) でも読み込めます。例えば `SKK-JISYO.L.gz` をそのまま辞書フォルダに置くことができます。

エンコーディングはファイル名から自動推測されます。ファイル名に `utf8` が含まれる場合はUTF-8、それ以外はEUC-JPとして扱われます。自動推測と異なるエンコーディングの場合は、辞書の `i` ボタンから手動で設定してください。

### 辞書の管理

- **有効/無効**: 各辞書のトグルで切り替えます
- **並び替え**: ドラッグで変換候補の優先順位を変更できます
- **辞書フォルダをFinderで表示**: Finderで辞書フォルダを開きます
- **削除**: ファイル自体をゴミ箱に移動または削除するとmacSKKが自動で無効化します

macSKK
====
macSKKはmacOS用の[SKK](https://ja.wikipedia.org/wiki/SKK)方式の日本語入力メソッドです。

macOS用のSKK方式の日本語入力メソッドにはすでに[AquaSKK](https://github.com/codefirst/aquaskk/)がありますが、いくつかやりたいことがあったため新たに作成しています。

## 特徴

- インプットメソッドはパスワードなどの機密情報を処理する可能性のある安全性が非常に求められるプログラムです。macOSのSandbox機構を使いNetwork機能やファイルの読み書きに制限をかけています。
- すべてをSwiftだけでコーディングしており、イベント処理にCombineを、UI部分にはSwiftUIを使用しています。

## 実装予定

- iCloudにマイ辞書を保存して他環境と共有できるようにする
- マイ辞書の暗号化
  - 編集したい場合は生データでのエクスポート & インポートできるようにする

## インストール

TODO

Mac App Storeでインプットメソッドを配布することができないため、[Appleのソフトウェア公証](https://support.apple.com/ja-jp/guide/security/sec3ad8e6e53/1/web/1)を受けたアプリケーションバイナリをpkgインストーラ形式で配布する予定です。

## アンインストール

TODO

インストーラにアンインストーラを同梱予定です。

手動で行うには、以下のファイルを削除してください。

- `~/Library/Input Methods/macSKK.app`
- `~/Library/Containers/net.mtgto.inputmethod.macSKK`

## 開発

Xcodeでビルドし、 `~/Library/Input Methods` に `macSKK.app` を配置してからキーボード環境設定で `ひらがな (macSKK)` などを追加してください。

SKK辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries` に配置してください。
ユーザー辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/skk-jisyo.utf8` にUTF-8形式で保存されます。

## ライセンス

macSKKはGNU一般公衆ライセンスv3またはそれ移行のバージョンの条項の元で配布されるフリー・ソフトウェアです。

詳細は `LICENSE` を参照してください。

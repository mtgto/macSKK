macSKK
====
macSKKはmacOS用の[SKK](https://ja.wikipedia.org/wiki/SKK)方式の日本語入力メソッドです。

macOS用のSKK方式の日本語入力メソッドにはすでに[AquaSKK](https://github.com/codefirst/aquaskk/)がありますが、いくつかやりたいことがあったため新たに作成しています。

## 特徴

- Swiftでコーディングしており、イベント処理にCombineを、UI部分にはSwiftUIを使用しています。
- インプットメソッドはパスワードなどの機密情報を処理する可能性のある安全性が非常に求められるプログラムです。macOSのSandbox機構を使いNetwork機能やファイルの読み書きに制限をかけています。

## インストール

TODO

Appleのソフトウェア公証を受けたアプリケーションバイナリをpkgインストーラ形式で配布する予定です。

## 開発

Xcodeでビルドし、 `~/Library/Input Methods` に `macSKK.app` を配置してからキーボード環境設定でひらがななどを追加してください。

辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries` に配置してください。
ユーザー辞書は `~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/skk-jisyo.utf8` にUTF-8形式で保存されます。

## ライセンス

macSKKはGNU一般公衆ライセンスv3またはそれ移行のバージョンの条項の元で配布されるフリー・ソフトウェアです。

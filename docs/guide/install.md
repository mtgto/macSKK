# インストール

## 動作環境

macOS 13.3 (Ventura) 以降が必要です。Universal Binary (Apple Silicon & Intel Mac) でビルドしています。

## インストール方法

Mac App Storeでは日本語入力システムを配布できないため、[Appleのソフトウェア公証](https://support.apple.com/ja-jp/guide/security/sec3ad8e6e53/1/web/1)を受けたバイナリを [GitHub Releases](https://github.com/mtgto/macSKK/releases/latest) で配布しています。

### DMGファイルからインストール

1. [GitHub Releases](https://github.com/mtgto/macSKK/releases/latest) から `.dmg` ファイルをダウンロード
2. DMGをマウントし、中の `.pkg` ファイルからインストール

### Homebrew Caskでインストール

```sh
brew install --cask macskk
```

詳細は https://formulae.brew.sh/cask/macskk を参照してください。

独自Cask定義 (`mtgto/macskk`) を使うと、GitHub Actionsで自動化されているためリリース直後に反映されます。

```sh
brew install --cask mtgto/macskk/macskk
```

詳細は https://github.com/mtgto/homebrew-macSKK を参照してください。

## インストール後の設定

### 入力ソースの追加

インストール後、**システム設定 → キーボード → 入力ソース** から以下を追加してください。

- **ひらがな** (アイコン: `▼あ`)
- **ABC** (アイコン: `▼A`)

カタカナ・全角英数・半角カナは任意です。

インストール直後に表示されない場合や、バージョンアップ後に反映されない場合はmacOSのログアウト & ログインを試してください。

### SKK辞書の配置

SKK辞書ファイルを以下のフォルダに配置してください。

```
~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries
```

まずは [skk-dev/dict](https://github.com/skk-dev/dict) の `SKK-JISYO.L` から使ってみることをおすすめします。

### 辞書の有効化

1. macOSメニューバーの**入力メニュー → 環境設定**を開く
2. 辞書設定で使用する辞書を有効に切り替える
3. EUC-JP以外のエンコーディングの場合は、`i` ボタンからエンコーディングを変更する

対応エンコーディング: **EUC-JP** (EUC-JIS-2004を含む)、**UTF-8**

辞書の削除は上記フォルダからファイルをゴミ箱に移動するか削除してください。macSKKが自動で無効化します。

### ユーザー辞書

ユーザー辞書は以下の場所にUTF-8形式で保存されます。

```
~/Library/Containers/net.mtgto.inputmethod.macSKK/Data/Documents/Dictionaries/skk-jisyo.utf8
```

ユーザー辞書はテキストエディタで直接編集することもできます。
macSKK以外のプロセスで更新された場合は自動で更新が反映されます。

## 基本的な使い方

### モードの切り替え

macSKKには複数の入力モードがあります。

| キー | 切り替え先 |
|---|---|
| `C-j` (Ctrl+J) | ひらがなモード |
| `l` | 直接入力（英数）モード |
| `q` | カタカナモード（ひらがなモードから） |
| `L` (Shift+L) | 全角英数モード |

### ひらがなの入力

ひらがなモードでローマ字を入力するとひらがなで入力されます。

```
nihongo → にほんご
```

### 漢字の変換（送り仮名なし）

漢字混じりで入力したい場合、変換したい読みの**最初の文字をShiftキーを押しながら**入力します。▽マーカーが表示され、読み入力モードになります。読みをすべて入力したらSpaceキーで変換を開始します。

```
Nihon → ▽にほん → Space → 日本
Kanji → ▽かんじ → Space → 漢字
```

- `Space` で次の候補へ
- `x` で前の候補に戻る
- `Enter` または変換後に続けて文字を入力して確定
- `Esc` または `C-g` でキャンセル

### 漢字の変換（送り仮名あり）

送り仮名のある漢字は、読みの入力中に**送り仮名の最初の文字をShiftキーを押しながら**入力します。

```
KaKu → ▽か*く → 書く   （「か」が読み、「く」が送り仮名）
OKi  → ▽お*き → 置き
```

辞書に候補がない場合は単語登録モードに入ります。詳細は[単語登録](../features/word-registration)を参照してください。

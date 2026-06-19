# よくある質問

::: info ドキュメントへのPull Requestについて
ドキュメントの誤りや不足に気づいた場合は、[Issue](https://github.com/mtgto/macSKK/issues) でお知らせください。Pull Requestは求めていません。
:::

## Visual Studio Code で `C-j` を押すと行末が削除される

`C-j` がVSCodeのキーボードショートカット `editor.action.joinLines` にデフォルトで割り当てられています。

`Cmd-K Cmd-S` から `editor.action.joinLines` を検索して、キーバインドを削除または変更してください。

## Wezterm で `C-j` を押すと改行される

[`macos_forward_to_ime_modifier_mask`](https://wezfurlong.org/wezterm/config/lua/config/macos_forward_to_ime_modifier_mask.html) に `CTRL` を追加することで、IMEに `C-j` が渡されてひらがなモードに切り替えできます。

`SHIFT` も必要なため、以下のように設定してください。

```lua
config.macos_forward_to_ime_modifier_mask = "SHIFT|CTRL"
```

## 標準Terminal / iTerm2 で `C-j` を押すと改行される

Karabiner-Elementsで `C-j` をかなキーに置換することで対応できます。以下のComplex Modificationsを `~/.config/karabiner/assets/complex_modifications/macskk.json` に配置してください。

```json
{
    "description": "macSKK for Terminal/iTerm2",
    "manipulators": [
        {
            "conditions": [
                {
                    "bundle_identifiers": [
                        "^com\\.googlecode\\.iterm2",
                        "^com\\.apple\\.Terminal"
                    ],
                    "type": "frontmost_application_if"
                },
                {
                    "input_sources": [
                        {
                            "input_source_id": "^net\\.mtgto\\.inputmethod\\.macSKK\\.(ascii|hiragana|katakana|hankaku|eisu)$"
                        }
                    ],
                    "type": "input_source_if"
                }
            ],
            "from": {
                "key_code": "j",
                "modifiers": {
                    "mandatory": ["left_control"]
                }
            },
            "to": [
                { "key_code": "japanese_kana" }
            ],
            "type": "basic"
        }
    ]
}
```

## Ghostty で `q`/`l` でモードが切り替わらない / `C-j` で改行される

Ghostty v1.1.0以降では、OS側の入力モードの変化を検知してキーを処理します。そのため、切り替え前後の入力モードを両方ともmacOSのキーボード設定で有効にする必要があります。

- `q` (カタカナ) が入力されてしまう場合: macSKKの「ひらがな」だけでなく「カタカナ」もシステムの入力ソースに追加してください
- `l` が入力されてしまう場合: macSKKの「ABC」をシステムの入力ソースに追加してください

参考: https://zenn.dev/mtgto/articles/macskk-karabiner-settings-for-ghostty

## VSCode ターミナル / Claude Code 拡張で `aiueo` がひらがなにならない

xterm.jsを使用するアプリの既知の問題です。([Issue #356](https://github.com/mtgto/macSKK/issues/356))

**入力メニュー → "1文字目を未確定扱い (互換性)"** を有効にすると `aiueo` のような1文字ローマ字からのひらがな入力ができるようになります。

::: warning
一時的なワークアラウンドです。`aiueo` 入力後は他のキーを打つかEnterを押すまで入力が確定されません。
:::

## `q`/`l` でモードが切り替わらない / `C-j` で改行される (その他のアプリ)

[Issue #119](https://github.com/mtgto/macSKK/issues/119) と同じ問題と思われます。**空文字挿入** のワークアラウンドを試してください。

対象アプリが最前面にある状態で **入力メニュー** から設定するか、**設定 → 互換性の設定** から設定できます。詳細は[互換性設定](./config/workaround)を参照してください。

## OS標準の入力ソースを削除してmacSKKだけにしたい

`日本語` の設定で入力モードの英字を有効にしてから `ABC`、`日本語` の順に削除するとmacSKKだけにできます。

参考: https://zenn.dev/yoshiyoshifujii/articles/78798db6472bf4

## ターミナルで「キーボード入力のセキュリティを保護」や iTerm2 の「Secure Keyboard Entry」を有効にすると入力メニューで無効化される

`Secure Keyboard Entry` が有効なアプリで日本語入力システムを使うには、システムライブラリ (`/Library`) にインストールされている必要があります。

v2.0.0からシステムライブラリへのインストールに対応しました。DMGからインストールするとシステムライブラリに配置されます。

参考: [Issue #351](https://github.com/mtgto/macSKK/issues/351)

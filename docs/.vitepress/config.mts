import { defineConfig } from "vitepress";

export default defineConfig({
  lang: "ja-JP",
  title: "macSKK",
  description: "macOS用SKK日本語入力システム",
  base: "/macSKK/",

  head: [
    ["link", { rel: "icon", type: "image/png", href: "/macSKK/favicon.png" }],
  ],

  themeConfig: {
    logo: "/icon.png",
    search: { provider: "local" },
    outline: { level: "deep" },

    nav: [
      { text: "ガイド", link: "/guide/install" },
      { text: "設定", link: "/config/" },
      { text: "機能", link: "/features/word-registration" },
      { text: "FAQ", link: "/faq" },
    ],

    sidebar: [
      {
        text: "ガイド",
        items: [
          { text: "インストール", link: "/guide/install" },
          { text: "アンインストール", link: "/guide/uninstall" },
        ],
      },
      {
        text: "設定",
        items: [
          { text: "設定の概要", link: "/config/" },
          { text: "一般", link: "/config/general" },
          { text: "辞書", link: "/config/dictionary" },
          { text: "変換候補パネル", link: "/config/candidate-window" },
          { text: "日付変換", link: "/config/date-conversion" },
          { text: "補完", link: "/config/completion" },
          { text: "キーバインド", link: "/config/keybinding" },
          { text: "ローマ字かな変換ルール", link: "/config/kana-rule" },
          { text: "ソフトウェアアップデート", link: "/config/software-update" },
          { text: "直接入力", link: "/config/direct-mode" },
          { text: "互換性の設定", link: "/config/workaround" },
          { text: "ログ", link: "/config/log" },
        ],
      },
      {
        text: "機能",
        items: [
          { text: "入力メニュー", link: "/features/input-menu" },
          { text: "単語登録", link: "/features/word-registration" },
          { text: "数値変換", link: "/features/numeric" },
          { text: "プライベートモード", link: "/features/private-mode" },
          { text: "バージョン自動チェック", link: "/features/version-check" },
        ],
      },
      {
        text: "FAQ",
        link: "/faq",
      },
    ],

    socialLinks: [{ icon: "github", link: "https://github.com/mtgto/macSKK" }],

    editLink: {
      pattern: "https://github.com/mtgto/macSKK/edit/main/docs/:path",
      text: "このページを編集",
    },

    footer: {
      message:
        'Released under the <a href="https://github.com/mtgto/macSKK/blob/main/LICENSE">GPLv3 License</a>.',
      copyright: 'Copyright © <a href="https://github.com/mtgto">mtgto</a>',
    },
  },
});

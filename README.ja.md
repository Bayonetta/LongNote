# LongNote

[English](README.md) · **[日本語](README.ja.md)** · [中文](README.zh-CN.md)

<div align="center">

[![CI](https://github.com/&lt;your-github-username&gt;/LongNote/actions/workflows/ci.yml/badge.svg)](https://github.com/&lt;your-github-username&gt;/LongNote/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)
![iOS 18+](https://img.shields.io/badge/iOS-18%2B-blue.svg)

</div>

**LongNote** — 微博クライアント「WeicoNote」の長文章機能に由来する、SwiftUI + TextKit 2 でゼロから再構築したデータドリブンなリッチテキスト / マルチメディアカードエディタです。Swift Package として提供し、ネットワーク連携（ログイン・素材・決済・投稿）はすべて除外しています。

## スクリーンショット

<p align="center">
  <img src="docs/screenshot-editor.png" width="270" alt="サンプル記事を開いたエディタ">
  <img src="docs/screenshot-drafts.png" width="270" alt="草稿リスト">
</p>

*リッチテキスト・混在ブロック・自動保存される草稿*

## LongNote とは

Swift Package Manager で配布できる、長文章（ロングリード）向けのリッチテキスト / マルチメディアカードエディタのコンポーネントライブラリです。微博（Weibo）クライアント「WeicoNote」の長文章機能に発想を得て、SwiftUI と TextKit 2 ですべてゼロから再構築しました。

オリジナルの優れていた部分をそのままに、ネットワークが必要な機能（アカウント、素材ライブラリ、決済、投稿）は意図的に含めていません。本パッケージは純粋に「オフライン編集 + 書き出し」のツールキットです。

## 主な機能

- **段落ごとのリッチテキスト編集** — 各段落が独立した `UITextView`（TextKit 2）。選択範囲単位の太字 / 取り消し線 / 色 / リンクが設定できます。
- **カバー画像・タイトル・リード文** — 16:9 のカバー、32 文字までのタイトル、任意のリード文。
- **混在排版（mixed blocks）** — 大見出し / 小見出し / 本文 / 引用 / リスト / 画像 / 分割線を一つのフロー内に混在させられます。
- **長画像（ロングイメージ）の書き出し** — SwiftUI `ImageRenderer` による描画と、超長文向けのタイル分割フォールバック。
- **草稿の自動保存** — ファイルベースの `ArticleStore`（記事ごとに 1 ディレクトリ）。入力停止 2 秒後に自動保存します。SwiftData への依存はありません。
- **カメラロール保存 / 共有** — Photos・`ShareLink`・`UIActivityViewController` に対応。

## 技術的なアピールポイント

**1. 編集操作をすべて純関数として実装**
Return・行頭 Backspace・複数行ペーストの分割・スタイル変換など、キーボード操作による段落の変化を `[Paragraph] -> ParagraphMutation.Result` の純関数に集約しました。UIKit に一切依存しないため、Linux / Windows を含む任意のプラットフォームで単体テストが実行できます（55 テスト）。

**2. SwiftUI × UITextView 橋渡し時のカーソルジャンプを解消**
段落ごとに `UITextView` を配置し、外部モデルと TextKit 内のテキストが**実際に異なるときだけ**テキストを再設定します。編集結果は delegate 経由で戻すため、双方向バインディングは使いません。行の高さは `layoutManager.usedRect` で計測して SwiftUI 側の行高さに反映しています。

**3. `@FocusState` の制約を `FocusCoordinator` で克服**
`UIViewRepresentable` には `@FocusState` を直接バインドできません。そこでフォーカス中の段落 ID と、分割・結合後のカーソル位置を運ぶコーディネータを実装し、命令的に first responder を操作しています。

**4. ポータブルなリッチテキストの永続化**
`CodableAttributedString` はリッチテキストを**セマンティックな run**（テキスト + 太字 / 斜体 / 取り消し線 / 色 / リンク）として保存します。`NSKeyedArchive` の不透明なブロブではなく可読な JSON なので、差分・検索・他言語での読み取りが可能です。v1 のアーカイブ形式も読み込め、次回保存時に v2 へ書き換わります（詳細は [`FORMAT.md`](FORMAT.md)）。

**5. 長画像書き出しのメモリ最適化**
数万字の記事を `ImageRenderer` で一度にオフスクリーン描画すると、数万ポイントの高さになりメモリが枯渇します。事前に `sizeThatFits` で計測し、単発描画とタイル分割描画を使い分け、安全なしきい値を超える場合はタイルセットでの共有を促す設計にしました。

**6. クロスプラットフォーム対応のパッケージ設計**
純 Foundation の `LongNoteCore` と UIKit 依存の `LongNote` をターゲット分割し、`#if canImport(UIKit)` で条件コンパイルしています。macOS / iOS でのフルビルドと、Windows / Linux でのコアテストを両立します。

## 動作環境

- Xcode 16 以降（Swift 6 ツールチェーン）
- iOS 18 以降（`@Observable`・TextKit 2・`ImageRenderer`・`PhotosPicker`・`ShareLink` を使用）

`LongNoteCore` ターゲットはプラットフォーム非依存です（モデル・段落変更アルゴリズム・ファイル保存は Foundation のみ）。`swift test` は Windows / Linux / macOS のいずれでも実行できます。

## インストール

Swift Package Manager：

```swift
dependencies: [
    .package(url: "https://github.com/<your-github-username>/LongNote.git", from: "1.0.0"),
]
```

ローカル開発では、このディレクトリを直接参照できます：

```swift
.package(path: "../LongNote")
```

## クイックスタート

```swift
import SwiftUI
import LongNote

struct MyEditorScreen: View {
    @State private var document: ArticleDocument?

    var body: some View {
        if let document {
            ArticleEditorView(document: document, onClose: { dismiss() }) {
                // export a long image
            }
        } else {
            ProgressView().task {
                let store = FileArticleStore()
                let article = Article.empty()   // or store.load(id)
                document = ArticleDocument(article: article, store: store)
            }
        }
    }
}
```

## 長画像の書き出し

```swift
let image = await ArticleImageRenderer.render(article) { fileName in
    guard let data = try? store.loadImage(fileName, for: article.id) else { return nil }
    return UIImage(data: data)
}
try? await image?.saveToPhotoLibrary()
```

超長文の場合は `ArticleImageRenderer.renderTiles(...)` で分割し、タイルセットとして共有してください — `Examples/LongNoteDemo/ExportView.swift` を参照。

## パッケージ構成

| ターゲット | 内容 | 対応プラットフォーム |
|---|---|---|
| `LongNoteCore` | `Model` / `Mutation`（ParagraphMutation）/ `Storage` / `TextStyle` | 任意（Foundation のみ） |
| `LongNote` | `Editor`（RichTextView ブリッジ・ビュー・ツールバー）/ `Rendering` / `RichText` | iOS 18 以降 |
| `LongNoteTests` | コアの単体テスト | 任意 |

`LongNote` は `LongNoteCore` を再エクスポートするので、`import LongNote` だけでモデルとストアも使えます。

```
Sources/
├── LongNoteCore/
│   ├── Model/          ParagraphKind · Paragraph · ParagraphImage · Article ·
│   │                   CodableAttributedString · TextRun · PlatformRichText
│   ├── Mutation/       ParagraphMutation — 分割 / 結合 / 変換 / ペースト / 挿入（純関数・テスト済み）
│   ├── Storage/        ArticleStore プロトコル · FileArticleStore
│   └── TextStyle/      フォントサイズ · 余白 · RGBA カラー（プラットフォーム非依存）
└── LongNote/
    ├── Editor/         ArticleDocument (@Observable) · FocusCoordinator · RichTextView ·
    │                   ArticleEditorView · ParagraphEditorView · 各ブロックビュー · ツールバー
    ├── Rendering/      ArticleRenderView · ArticleImageRenderer（タイル分割・写真保存）
    └── RichText/       NSAttributedString / HTML / AttributedString ヘルパー
```

## テスト

```sh
# macOS / Linux / Windows — コアのテストはどこでも実行できます：
swift test --filter LongNoteTests
```

Mac では `swift build` / `swift test` で iOS UI を含むすべてがコンパイルされます。エディタ自体の動作は Xcode で `LongNoteDemo` を実行して確認できます。

## デモアプリ

`Examples/LongNoteDemo/` に最小構成の iOS アプリ（草稿リスト → エディタ → 長画像プレビュー → 保存 / 共有）があります。初回起動時にサンプル記事が自動で読み込まれ、すぐにエディタの全画面を確認できます。Xcode プロジェクトは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で生成します：

```sh
cd Examples/LongNoteDemo
xcodegen generate
open LongNoteDemo.xcodeproj
```

詳細と XcodeGen を使わない手順は `Examples/LongNoteDemo/README.md` を参照してください。

## 保存形式

草稿は「1 記事 = 1 ディレクトリ」で、JSON ドキュメントと画像ファイルから成ります。リッチテキストはセマンティックな run として保存されるため、ファイルは可読かつ可搬です：

```json
"text": { "runs": [ { "text": "A paragraph with " },
                    { "text": "bold", "bold": true },
                    { "text": " and a " },
                    { "text": "link", "link": "https://example.com" } ] }
```

スキーマ全体・v1 との互換ルール・移行手順は [`FORMAT.md`](FORMAT.md) にまとめています。

## 設計のポイント

**一段落、一 `UITextView`。** SwiftUI の `TextEditor` は選択範囲の属性制御や選択位置の取得ができません。そこで `UIViewRepresentable`（`RichTextView`）で `UITextView` を橋渡ししています：

- **カーソルジャンプなし** — 外部値と実際の表示が違うときだけテキストを再設定。編集は delegate で戻します。
- **高さの自動追従** — `layoutManager.usedRect` で計測した高さを行の高さとして適用。キャッシュした高さを持ちません。

**編集ルールは純関数。** `ParagraphMutation` はキーボードの操作を `[Paragraph] -> Result` 変換に写像します：

| 操作 | 動作 |
|---|---|
| Return | カーソル位置で分割。後半が新しい段落に（リストは継続） |
| 行頭で Backspace | 前の段落に結合（分割線・画像はスキップ / 削除） |
| 空のリスト項目で Return | リストを解除して本文に変換 |
| 複数行ペースト | 1 行 = 1 段落に分割 |
| 分割線の挿入 | 現在の段落の直後に挿入し、その下の行にカーソルを移す（余分な空行は作らない） |
| 画像の挿入 | 前後に空の本文段落を足してからフォーカスを移動 |

**フォーカス。** `@FocusState` は `UIViewRepresentable` に直接バインドできません。`FocusCoordinator` がフォーカス中の段落 ID を記録し、各テキストビューが first responder になります。分割・結合後はカーソル位置も運びます。

**長画像のメモリ対策。** `ImageRenderer` は `scale` でオフスクリーン描画します。3 万字の記事は数万ポイントの高さになり、そのままではメモリが爆発します。`ArticleImageRenderer` は (1) `sizeThatFits` で事前計測し、(2) `maxSingleHeight`（既定 5000 pt）に収まる場合は一括描画、(3) 超える場合は `maxTileHeight` のタイルに分割して描画・連結、(4) 連結後も安全なピクセル高を超える場合は `render(_:)` が `nil` を返し、呼び出し側に `renderTiles(_:)` を提示する、という流れです。

## 原案とスコープ

微博「头条文章专业版」（2015 年・iOS 8・Objective-C）の**エディタ中核**、および微博クライアント「WeicoNote」の長文章機能に由来するクリーンルーム実装です。アカウント体系・素材ライブラリ・決済・投稿機能は意図的に移植していません。本パッケージはオフラインの編集・書き出しツールキットであり、MIT ライセンスで提供されます。

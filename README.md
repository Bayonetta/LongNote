# LongNote

**[English](README.md)** · [日本語](README.ja.md) · [中文](README.zh-CN.md)

[![CI](https://github.com/Bayonetta/LongNote/actions/workflows/ci.yml/badge.svg)](https://github.com/Bayonetta/LongNote/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange.svg)
![iOS 18+](https://img.shields.io/badge/iOS-18%2B-blue.svg)

**LongNote** — a pure Swift Package that rebuilds the long-article feature of WeicoNote, a popular Weibo client, as a data-driven rich-text / multimedia card editor, in SwiftUI + TextKit 2, with all networking and platform integration stripped out.

## Screenshots

![LongNote editor with a sample article, and the draft list](docs/screenshots.png)

*Editor with rich text, mixed block types and autosaved drafts*

## What is LongNote

A **pure Swift Package** component library that descends from the long-article feature of WeicoNote, a popular Weibo client, and rebuilds it from scratch in SwiftUI + TextKit 2 — with all networking (login, material library, payment, publishing) stripped out.

You get the parts that made the original editor great:

- **Per-paragraph rich text** — each paragraph is a `UITextView` (TextKit 2), giving full per-run control over bold / strikethrough / color / link, exactly like the original one-paragraph-per-row list.
- **Cover / title / summary** — 16:9 cover, 32-character title, optional lede.
- **Mixed blocks** — H1 / H2 / body / quote / list / image / divider in one flow.
- **Long-image export** — SwiftUI `ImageRenderer` with a tiling fallback for very long articles.
- **Draft autosave** — a tiny file-based `ArticleStore` (one directory per article), autosaved with a 2 s debounce. The library does not bind you to SwiftData.
- **Save to Photos / share** — via Photos / `ShareLink` / `UIActivityViewController`.

## Technical highlights

**1. Editing rules are pure functions.** `ParagraphMutation` maps every keyboard gesture — Return split, backspace-at-start merge, multi-line paste, style conversion, block insertion — to a `[Paragraph] -> Result` transformation. Nothing touches UIKit, so the logic is unit-tested (55 tests) on any platform, including Linux and Windows.

**2. No cursor jumps in the SwiftUI ↔ UITextView bridge.** One `UITextView` per paragraph, bridged through a `UIViewRepresentable` (`RichTextView`). The text is re-set only when the external value actually differs from the text view's content; edits flow back through the delegate, never through two-way binding. Row height comes from `layoutManager.usedRect`, applied as an explicit height — no cached heights.

**3. `@FocusState` can't reach a `UIViewRepresentable` — so a `FocusCoordinator` does.** It records the focused paragraph id, drives first responder per text view, and carries a requested cursor position after splits and merges.

**4. Portable rich-text persistence.** `CodableAttributedString` stores rich text as **semantic runs** — text plus bold / italic / strikethrough / colour / link — instead of an opaque `NSKeyedArchive` blob. The document JSON stays readable, diffable and searchable, and works outside Apple platforms. v1 archives still decode and are rewritten as v2 on the next save (see [`FORMAT.md`](FORMAT.md)).

**5. Memory-safe long-image export.** A 30k-character article is tens of thousands of points tall — rendering it whole would exhaust memory. `ArticleImageRenderer` measures first (`sizeThatFits`), renders in one shot when it fits `maxSingleHeight` (default 5000 pt), otherwise renders `maxTileHeight` tiles and stitches them, and returns `nil` when even the stitched image would exceed a safe pixel height so callers can offer `renderTiles(_:)` as a set instead.

**6. Cross-platform package architecture.** `LongNoteCore` (Foundation-only) and `LongNote` (UIKit) are separate targets, with `#if canImport(UIKit)` conditional compilation — full builds on macOS/iOS and core tests on Windows/Linux from one source tree.

## Requirements

- Xcode 16+ (Swift 6 toolchain)
- iOS 18+ (uses `@Observable`, TextKit 2, `ImageRenderer`, `PhotosPicker`, `ShareLink`)

The **core** (`LongNoteCore` target) is platform-independent: models, paragraph mutation algorithms and file storage use only Foundation, so `swift test` runs on Windows / Linux as well as macOS.

## Installation

Swift Package Manager:

```swift
dependencies: [
    .package(url: "https://github.com/YOUR_GITHUB_USERNAME/LongNote.git", from: "1.0.0"),
]
```

For local development, point at this directory:

```swift
.package(path: "../LongNote")
```

## Quick start

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

## Export a long image

```swift
let image = await ArticleImageRenderer.render(article) { fileName in
    guard let data = try? store.loadImage(fileName, for: article.id) else { return nil }
    return UIImage(data: data)
}
try? await image?.saveToPhotoLibrary()
```

For very long articles use `ArticleImageRenderer.renderTiles(...)` and share the resulting set — see `Examples/LongNoteDemo/ExportView.swift`.

## Package layout

| Target | Contents | Platforms |
|---|---|---|
| `LongNoteCore` | `Model`, `Mutation` (ParagraphMutation), `Storage`, `TextStyle` | any (Foundation only) |
| `LongNote` | `Editor` (RichTextView bridge, views, toolbars), `Rendering`, `RichText` | iOS 18+ |
| `LongNoteTests` | Unit tests for the core | any |

`LongNote` re-exports `LongNoteCore`, so `import LongNote` brings in the models and store alongside the UI.

```
Sources/
├── LongNoteCore/
│   ├── Model/          ParagraphKind · Paragraph · ParagraphImage · Article ·
│   │                   CodableAttributedString · TextRun · PlatformRichText
│   ├── Mutation/       ParagraphMutation — split/merge/convert/paste/insert (pure, unit-tested)
│   ├── Storage/        ArticleStore protocol · FileArticleStore
│   └── TextStyle/      font sizes · spacing · RGBA colors (platform-neutral)
└── LongNote/
    ├── Editor/         ArticleDocument (@Observable) · FocusCoordinator · RichTextView ·
    │                   ArticleEditorView · ParagraphEditorView · block views · toolbars
    ├── Rendering/      ArticleRenderView · ArticleImageRenderer (+ tile fallback, photo save)
    └── RichText/       NSAttributedString HTML/AttributedString helpers
```

## Tests

```sh
# macOS / Linux / Windows — the core tests run anywhere:
swift test --filter LongNoteTests
```

On a Mac, `swift build` / `swift test` compile everything (including the iOS UI). The editor itself is exercised by running `LongNoteDemo` in Xcode.

## Demo app

`Examples/LongNoteDemo/` contains a minimal iOS app (draft list → editor → long-image preview → save/share). It seeds a fully-populated sample article on first launch, so the editor can be inspected immediately — and screenshots are representative. Generate its Xcode project with [XcodeGen](https://github.com/yonaskolb/XcodeGen):

```sh
cd Examples/LongNoteDemo
xcodegen generate
open LongNoteDemo.xcodeproj
```

See `Examples/LongNoteDemo/README.md` for details and a no-XcodeGen route.

## Storage format

Each draft is a directory with one JSON document plus its images. Rich text is
stored as semantic runs, so the file stays readable and portable:

```json
"text": { "runs": [ { "text": "A paragraph with " },
                    { "text": "bold", "bold": true },
                    { "text": " and a " },
                    { "text": "link", "link": "https://example.com" } ] }
```

The full schema, the v1 compatibility rules and the migration steps are in
[`FORMAT.md`](FORMAT.md).

## Origin & scope

LongNote descends from the long-article feature of WeicoNote, a popular Weibo client (2015, iOS 8, Objective-C), rebuilt from scratch as a modern Swift package. The account system, material library, payment, and publishing features were deliberately **not** ported — this package is purely an offline editing + export toolkit, licensed under the MIT License.

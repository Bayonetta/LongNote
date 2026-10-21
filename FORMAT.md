# LongNote document format

A draft is a directory per article. Everything is plain UTF-8 JSON plus image
files, so a document can be inspected, diffed and migrated by hand.

```
Documents/Articles/
  <article-uuid>/
    article.json      ← the whole document (schemaVersion 2)
    images/
      <file-name>     ← image data referenced by cover / paragraph images
```

## `article.json`

```json
{
  "schemaVersion": 2,
  "id": "AB76887C-4411-4A7A-89BC-48AEAFED25FD",
  "title": "Apple Supercharges Its Tools and Technologies for Developers",
  "summary": "Access to the on-device Apple Intelligence model …",
  "cover": { "fileName": "cover-….jpg", "width": 1600, "height": 900 },
  "paragraphs": [ … ],
  "createdAt": 1761080213.42,
  "updatedAt": 1761080213.42
}
```

| Field | Notes |
|---|---|
| `schemaVersion` | `1` for documents written before v2 (the key is absent there); `2` from this version on |
| `id` | Stable identity, also the directory name |
| `title` / `summary` | Plain strings; `summary` may be absent |
| `cover` | Optional 16:9 banner; `fileName` resolves inside `images/` |
| `paragraphs` | Ordered block list — the document body |
| `createdAt` / `updatedAt` | Seconds since 2001 (JSON `Date` default encoding) |

## Paragraphs

```json
{
  "id": "3AA7C7F9-C073-4D4A-8946-97BC0945E5C0",
  "kind": "body",
  "text": { … },
  "image": null,
  "isLastInList": false
}
```

`kind` is one of `title` (H1), `header` (H2), `body`, `quote`, `list`, `image`,
`divider`. `image` is only present for `kind: "image"`:

```json
{ "fileName": "figure-….jpg", "width": 1200, "height": 800, "caption": "Figure — …" }
```

`isLastInList` is a denormalised flag that controls the extra bottom spacing
after a run of list items; `ParagraphMutation.normalize(_:)` keeps it correct
after every edit.

## Rich text (`text`)

Three shapes are accepted on read; the first two are written.

### 1. Plain text

```json
"text": { "string": "A New Design, More Focus on Content" }
```

Used whenever the text carries no styling — keeps simple documents tiny.

### 2. Semantic runs (v2)

```json
"text": {
  "runs": [
    { "text": "CUPERTINO, CALIFORNIA Apple today announced … A " },
    { "text": "beautiful new software design", "bold": true },
    { "text": " joins a suite of tools … The " },
    { "text": "Foundation Models framework", "color": [0.16, 0.5, 0.97, 1] },
    { "text": " and " },
    { "text": "Xcode 26", "link": "https://www.apple.com/newsroom/…" }
  ]
}
```

| Run field | Type | Meaning |
|---|---|---|
| `text` | String | The run's characters (required) |
| `bold` / `italic` | Bool | Omitted when false |
| `strike` | Bool | Strikethrough |
| `color` | `[r, g, b, a]` | sRGB, each 0…1; `a` optional (defaults to 1) |
| `link` | URL string | Omitted when absent |

**A run carries deviations only.** Point sizes and platform font/colour objects
are deliberately not stored: typography belongs to the block (`ParagraphKind`),
so the same document renders identically on any platform, and switching a
block's style never rewrites its text. A run whose colour equals the default
text colour is written without `color`.

### 3. Keyed archive (v1, read-only)

```json
"text": { "archive": "<base64 of an NSKeyedArchiver payload>" }
```

Documents written by schema v1 embedded the whole `NSAttributedString`. These
still decode (on Apple platforms), and the next save rewrites them as runs.

## Compatibility notes

- **Forward**: an older reader meeting a v2 document sees `runs` and cannot
  render styling; it should fall back to concatenating `text`.
- **Backward**: v1 files load unchanged; `FileArticleStore` upgrades them in
  memory (`Article.migrated()`) and persists v2 on the next save.
- **Other platforms**: the file is fully readable everywhere. On Linux/Windows
  the in-memory `NSAttributedString` loses styling when decoding runs (no UIKit),
  but the stored document keeps it.

## Changing the format

1. Bump `Article.currentSchemaVersion`.
2. Teach the decoder to read both shapes (add a new `CodingKeys` case rather than
   repurposing an existing one).
3. Add the upgrade step to `Article.migrated()`.
4. Add a round-trip test in `Tests/LongNoteTests/RichTextRunTests.swift` and a
   "previous version still loads" test.

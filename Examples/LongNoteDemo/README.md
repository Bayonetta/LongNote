# LongNoteDemo

A minimal iOS app that exercises the full LongNote flow: **new draft → edit → draft list → export long image → save/share**.

This app is iOS-only (it depends on the UIKit-backed `LongNote` target), so it
cannot be built on Windows. The LongNote core is platform-independent and can be
tested anywhere via `swift test` (see the repo README).

## Build & run

You need a Mac with Xcode 16+.

**Option A — XcodeGen (recommended):**

```sh
brew install xcodegen
cd Examples/LongNoteDemo
xcodegen generate
open LongNoteDemo.xcodeproj
```

Select the `LongNoteDemo` scheme and run on an iOS 18 simulator or device.

**Option B — plain Xcode:**

1. `File → New → Project → iOS → App`, name it `LongNoteDemo`.
2. Delete the generated `ContentView.swift`.
3. Drag `LongNoteDemo/` (the Swift files in this folder) into the target.
4. `File → Add Package Dependencies…`, add the repo root (this repository) as a
   local package.
5. In the target's `Build Settings`, add
   `NSPhotoLibraryAddUsageDescription` to the Info tab (the generated
   `Info.plist`) with a description, and set the deployment target to iOS 18.
6. Build & run.

## What to try

- On first launch the app loads a fully-populated **sample article** and opens
  it straight in the editor: news-style body copy with bold and colored runs,
  an inline link, every block style (H1 / H2 / body / quote / list / divider),
  a generated cover image and an inline figure. Delete it from the draft list
  and use *Load Sample Article* to bring it back.
- Type a title, add a cover, write a summary.
- Press Return to split paragraphs, Backspace at a line start to merge them back.
- The compose bar floats on the keyboard: tap into a paragraph to bring it up
  (switch to H1/H2/quote/list, insert a divider or an image with a caption, add
  a link), and dismiss the keyboard to hide it again.
- Select text and use the floating toolbar for bold / strikethrough / color /
  link.
- Tap the share icon, then **Save to Photos** or **Share**.
- Kill and relaunch the app — drafts survive (autosave 2 s after your last edit).

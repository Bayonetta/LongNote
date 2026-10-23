#if canImport(UIKit)
  import SwiftUI
  import UIKit
  import LongNoteCore

  /// A `UITextView` (TextKit 2) bridged into SwiftUI — the workhorse of the editor.
  ///
  /// Design goals:
  /// - **No cursor jumping.** `updateUIView` only resets the text when the external
  ///   value actually differs from what's in the text view. User edits are reported
  ///   back through `onTextChange`, never by two-way binding.
  /// - **Height reporting.** `onHeightChange` emits the laid-out height so the
  ///   SwiftUI row can size itself (`isScrollEnabled = false` + `allowsNonContiguousLayout
  ///   = false` keeps the measurement exact).
  /// - **Keyboard routing.** Return, backspace-at-start and multi-line paste are
  ///   intercepted and handed to the editor (`ParagraphMutation`) instead of being
  ///   typed into the paragraph.
  /// - **Imperative styling.** `actionToApply` delivers a `RichTextAction` to the
  ///   live text view (selection + typing attributes) and then reports back.
  struct RichTextView: UIViewRepresentable {
    /// Current value. Re-set in `updateUIView` only when it differs.
    var text: NSAttributedString
    var placeholder: String?
    var isFocused: Bool
    /// True when no paragraph holds focus at all (the editor dismissed the
    /// keyboard). When focus merely moves to a sibling paragraph this stays
    /// false so this view keeps first responder until the sibling takes over —
    /// resigning first would drop the keyboard and make it pop back up.
    var shouldResign: Bool = false
    var textInsets: UIEdgeInsets = .zero
    /// Programmatic selection to apply once focused (split/merge cursor placement).
    var selection: NSRange?
    /// Styling action to apply to the live text view (nil = nothing to do).
    var actionToApply: RichTextAction?
    /// Selection to apply the action to, captured when the toolbar's prompt
    /// opened (the alert resigns first responder and clears the live one).
    var actionSelection: NSRange?
    /// Attributes for new text before the user has made any formatting choice.
    var initialTypingAttributes: [NSAttributedString.Key: Any]?

    var onTextChange: ((NSAttributedString) -> Void)?
    var onReturn: ((NSRange) -> Void)?
    var onBackspaceAtStart: (() -> Void)?
    var onDashSpace: (() -> Void)?
    var onPasteSplit: ((NSRange, String) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?
    var onBeginEditing: (() -> Void)?
    var onEndEditing: (() -> Void)?
    var onActionApplied: (() -> Void)?
    var onSelectionConsumed: (() -> Void)?

    func makeCoordinator() -> Coordinator {
      Coordinator(self)
    }

    func makeUIView(context: Context) -> UITextView {
      let textView = LongNoteTextView()
      textView.delegate = context.coordinator
      textView.isScrollEnabled = false
      textView.isEditable = true
      textView.isSelectable = true
      textView.layoutManager.allowsNonContiguousLayout = false
      textView.textContainer.lineFragmentPadding = 0
      textView.textContainerInset = textInsets
      textView.backgroundColor = .clear
      textView.attributedText = text
      textView.typingAttributes =
        initialTypingAttributes
        ?? [
          .font: UIFont.systemFont(ofSize: TextStyle.bodyFontSize),
          .foregroundColor: TextStyle.textColor.uiColor,
        ]

      return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
      let coordinator = context.coordinator
      coordinator.representable = self

      // 1. Sync text only when the *content* really changed (prevents cursor
      //    jumps).
      //
      //    `isEqual(to:)` is the wrong test here. The value handed in is
      //    `styledText(kind)`, which always carries the block's paragraph style
      //    and base font, while the live text view holds whatever TextKit kept —
      //    freshly typed characters get the typing attributes (no paragraph
      //    style), so the two are never equal. Every update pass therefore
      //    replaced the whole string, which parks the caret at the end of the
      //    text and throws away the styling the toolbar had just applied.
      //    Semantic equality (characters + bold/italic/strike/colour/link) is
      //    the right comparison: typography is derived from the kind, not part
      //    of the document.
      let current = CodableAttributedString(
        textView.attributedText ?? NSAttributedString(string: ""))
      if current != CodableAttributedString(text) {
        let caret = textView.selectedRange
        coordinator.isProgrammaticChange = true
        textView.attributedText = text
        // Replacing `attributedText` moves the selection to the very end; put
        // the caret back so a legitimate resync doesn't read as "focus jumped
        // to the end of the line".
        let length = textView.textStorage.length
        let location = min(caret.location, length)
        textView.selectedRange = NSRange(
          location: location, length: min(caret.length, length - location))
        coordinator.isProgrammaticChange = false
      }

      // 2. Placeholder redraw.
      (textView as? LongNoteTextView)?.placeholder = placeholder
      textView.setNeedsDisplay()

      // 3. Focus. Deferred so it runs after the view is attached to the window.
      // Re-check the coordinator's *current* representable at fire time so a
      // focus change in the meantime is respected.
      if isFocused, !textView.isFirstResponder {
        DispatchQueue.main.async { [weak coordinator] in
          guard let coordinator else { return }
          if coordinator.representable.isFocused, !textView.isFirstResponder {
            textView.becomeFirstResponder()
          }
        }
      } else if !isFocused, textView.isFirstResponder, shouldResign {
        textView.resignFirstResponder()
      }

      // 4. Programmatic selection.
      if isFocused, let selection {
        if selection != textView.selectedRange {
          coordinator.isProgrammaticChange = true
          textView.selectedRange = selection
          coordinator.isProgrammaticChange = false
        }
        // Consume the request even when it already matched. A request that is
        // left sitting in the coordinator gets re-applied on the next update
        // pass and yanks the caret back to a stale range while the user types —
        // the "focus jumps around on its own" symptom. Clearing it mutates
        // observed state, so do it after the current pass.
        DispatchQueue.main.async { [weak coordinator] in
          coordinator?.representable.onSelectionConsumed?()
        }
      }

      // 5. Styling action (applied exactly once per distinct action).
      if let action = actionToApply {
        if coordinator.lastAppliedAction != action {
          coordinator.lastAppliedAction = action
          restoreActionSelection(in: textView, coordinator: coordinator)
          textView.applyRichTextAction(action)
          // Attribute-only text-storage edits do not fire `textViewDidChange`,
          // so push the styled text back into the model explicitly. Without
          // this the next update pass resets `attributedText` from the stale
          // model and the new style silently disappears.
          onTextChange?(textView.attributedText ?? NSAttributedString(string: ""))
        }
        onActionApplied?()
        // The document has cleared its pending action synchronously; forget the
        // marker so the same action can be applied again (bold → unbold uses
        // the same case).
        coordinator.lastAppliedAction = nil
      }
    }

    /// Puts the selection captured when the prompt opened back into the text
    /// view, so the action lands on the same range the user had selected.
    private func restoreActionSelection(in textView: UITextView, coordinator: Coordinator) {
      guard let actionSelection else { return }
      let length = textView.textStorage.length
      let location = min(max(actionSelection.location, 0), length)
      let range = NSRange(
        location: location, length: min(actionSelection.length, length - location))
      if range != textView.selectedRange {
        coordinator.isProgrammaticChange = true
        textView.selectedRange = range
        coordinator.isProgrammaticChange = false
      }
    }

    static func dismantleUIView(_ textView: UITextView, coordinator: Coordinator) {
      textView.delegate = nil
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
      var representable: RichTextView
      var isProgrammaticChange = false
      var lastAppliedAction: RichTextAction?

      init(_ representable: RichTextView) {
        self.representable = representable
        super.init()
      }

      // MARK: UITextViewDelegate

      func textViewDidChange(_ textView: UITextView) {
        guard !isProgrammaticChange else { return }
        representable.onTextChange?(textView.attributedText ?? NSAttributedString(string: ""))
      }

      func textViewDidChangeSelection(_ textView: UITextView) {
        guard !isProgrammaticChange else { return }
        representable.onSelectionChange?(textView.selectedRange)
      }

      func textViewDidBeginEditing(_ textView: UITextView) {
        representable.onBeginEditing?()
      }

      func textViewDidEndEditing(_ textView: UITextView) {
        representable.onEndEditing?()
      }

      func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
      ) -> Bool {
        // Return key → editor splits paragraphs.
        if text == "\n" {
          representable.onReturn?(textView.selectedRange)
          return false
        }
        // Backspace at the very start → editor merges into the previous paragraph.
        if text.isEmpty, range.location == 0, range.length == 0,
          representable.onBackspaceAtStart != nil
        {
          representable.onBackspaceAtStart?()
          return false
        }
        // "- " at the start of a paragraph → convert it to a list item.
        // Handles both a pasted/autocompleted "- " (range at 0) and a dash typed
        // character-by-character (the dash is already in the text; the space is
        // the current keystroke).
        let leadingDashes = ["-", "–", "—"]
        if representable.onDashSpace != nil, range.length == 0 {
          let beforeCursor = (textView.text as NSString).substring(to: range.location)
          let isPastedDash = range.location == 0 && (text == "- " || text == "– " || text == "— ")
          let isTypedDashSpace = leadingDashes.contains(beforeCursor) && text == " "
          if isPastedDash || isTypedDashSpace {
            representable.onDashSpace?()
            return false
          }
        }
        // Pasting multiple lines → editor splits them into paragraphs.
        if text.contains("\n"), text != "\n", representable.onPasteSplit != nil {
          representable.onPasteSplit?(range, text)
          return false
        }
        return true
      }

  }

  /// Internal `UITextView` subclass that draws a placeholder when empty and
  /// opts out of intrinsic sizing (see the comment below).
  ///
  /// Internal (not private) so `sizeThatFits(_:uiView:context:)` above can name
  /// it in an internal signature — a fileprivate witness is not picked up by
  /// SwiftUI's representable sizing.
  final class LongNoteTextView: UITextView {
    var placeholder: String?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
      super.init(frame: frame, textContainer: textContainer)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(textChanged),
        name: UITextView.textDidChangeNotification,
        object: self
      )
    }

    /// Report *no* intrinsic size.
    ///
    /// A `UITextView` with `isScrollEnabled = false` reports the full unwrapped
    /// text as its intrinsic content size (a 4,000-character paragraph wants a
    /// 5,000 pt-wide view!). When SwiftUI takes that as the representable's
    /// size, the text lays out on one enormous line and runs off both screen
    /// edges. Opting out lets SwiftUI propose the real layout width, so the
    /// text wraps at the available width; the row height is driven by
    /// `RichTextView`'s reported height instead.
    override var intrinsicContentSize: CGSize {
      CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    required init?(coder: NSCoder) {
      fatalError("LongNoteTextView is code-only")
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
    }

    @objc private func textChanged(_ notification: Notification) {
      setNeedsDisplay()
    }

    override func draw(_ rect: CGRect) {
      super.draw(rect)
      guard let placeholder, text.isEmpty else { return }
      let font =
        self.font ?? (typingAttributes[.font] as? UIFont)
        ?? UIFont.systemFont(ofSize: TextStyle.bodyFontSize)
      let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: TextStyle.placeholderColor.uiColor,
      ]
      let point = CGPoint(
        x: textContainerInset.left + textContainer.lineFragmentPadding,
        y: textContainerInset.top
      )
      (placeholder as NSString).draw(at: point, withAttributes: attributes)
    }
  }
}
#endif

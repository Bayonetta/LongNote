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
    var textInsets: UIEdgeInsets = .zero
    /// Programmatic selection to apply once focused (split/merge cursor placement).
    var selection: NSRange?
    /// Styling action to apply to the live text view (nil = nothing to do).
    var actionToApply: RichTextAction?
    /// Attributes for new text before the user has made any formatting choice.
    var initialTypingAttributes: [NSAttributedString.Key: Any]?

    var onTextChange: ((NSAttributedString) -> Void)?
    var onReturn: ((NSRange) -> Void)?
    var onBackspaceAtStart: (() -> Void)?
    var onDashSpace: (() -> Void)?
    var onPasteSplit: ((NSRange, String) -> Void)?
    var onSelectionChange: ((NSRange) -> Void)?
    var onHeightChange: ((CGFloat) -> Void)?
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

      // Re-report the height whenever the view lays out (the width may not be
      // final on the first `updateUIView`, so a stale first measurement is
      // corrected here).
      let coordinator = context.coordinator
      textView.onLayoutSubviews = { [weak coordinator, weak textView] in
        guard let coordinator, let textView else { return }
        coordinator.reportHeight(textView)
      }
      return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
      let coordinator = context.coordinator
      coordinator.representable = self

      // 1. Sync text only when it really changed (prevents cursor jumps).
      let current = textView.attributedText ?? NSAttributedString(string: "")
      if !current.isEqual(to: text) {
        coordinator.isProgrammaticChange = true
        textView.attributedText = text
        coordinator.isProgrammaticChange = false
      }

      // Report height on every pass; the coordinator's `lastReportedHeight`
      // guard makes this a no-op unless it actually changed (this also covers
      // the first layout, when the text was already set in `makeUIView`).
      coordinator.reportHeight(textView)

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
      } else if !isFocused, textView.isFirstResponder {
        textView.resignFirstResponder()
      }

      // 4. Programmatic selection.
      if isFocused, let selection, selection != textView.selectedRange {
        coordinator.isProgrammaticChange = true
        textView.selectedRange = selection
        coordinator.isProgrammaticChange = false
        onSelectionConsumed?()
      }

      // 5. Styling action (applied exactly once per distinct action).
      if let action = actionToApply {
        if coordinator.lastAppliedAction != action {
          coordinator.lastAppliedAction = action
          textView.applyRichTextAction(action)
        }
        onActionApplied?()
      }
    }

    static func dismantleUIView(_ textView: UITextView, coordinator: Coordinator) {
      textView.delegate = nil
    }

    /// Always take the width SwiftUI proposes.
    ///
    /// Without this the representable is sized to the text view's *intrinsic*
    /// content size — for a `UITextView` with scrolling disabled that is the
    /// full unwrapped text width. Short paragraphs happen to fit on screen;
    /// long ones lay out far wider than the screen and run off both edges
    /// (and their first characters become invisible). Returning the proposal
    /// pins the text container to the available width so text wraps normally.
    /// `fileprivate` because `LongNoteTextView` is a private type.
    fileprivate func sizeThatFits(
      _ proposal: ProposedViewSize, uiView: LongNoteTextView, context: Context
    ) -> CGSize? {
      let width = proposal.width ?? (uiView.frame.width > 0 ? uiView.frame.width : 320)
      let height = proposal.height ?? uiView.frame.height
      return CGSize(width: width, height: height)
    }

    // MARK: - Coordinator

    @MainActor
    final class Coordinator: NSObject, UITextViewDelegate {
      var representable: RichTextView
      var isProgrammaticChange = false
      var lastAppliedAction: RichTextAction?
      private var lastReportedHeight: CGFloat = -1

      init(_ representable: RichTextView) {
        self.representable = representable
        super.init()
      }

      // MARK: UITextViewDelegate

      func textViewDidChange(_ textView: UITextView) {
        guard !isProgrammaticChange else { return }
        representable.onTextChange?(textView.attributedText ?? NSAttributedString(string: ""))
        reportHeight(textView)
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

      // MARK: Height

      func reportHeight(_ textView: UITextView) {
        let layoutManager = textView.layoutManager
        layoutManager.ensureLayout(for: textView.textContainer)
        let used = layoutManager.usedRect(for: textView.textContainer)
        let inset = textView.textContainerInset
        let height = ceil(used.height + inset.top + inset.bottom)
        guard height != lastReportedHeight else { return }
        lastReportedHeight = height
        representable.onHeightChange?(height)
      }
    }
  }

  /// Internal `UITextView` subclass that draws a placeholder when empty and reports
  /// layout passes so the SwiftUI row height stays exact.
  private final class LongNoteTextView: UITextView {
    var placeholder: String?
    var onLayoutSubviews: (() -> Void)?

    override init(frame: CGRect, textContainer: NSTextContainer?) {
      super.init(frame: frame, textContainer: textContainer)
      NotificationCenter.default.addObserver(
        self,
        selector: #selector(textChanged),
        name: UITextView.textDidChangeNotification,
        object: self
      )
    }

    override func layoutSubviews() {
      super.layoutSubviews()
      onLayoutSubviews?()
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
#endif

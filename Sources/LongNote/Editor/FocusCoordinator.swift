#if canImport(UIKit)
  import Foundation
  import Observation
  import LongNoteCore

  /// Tracks which paragraph currently has keyboard focus and coordinates
  /// programmatic cursor placement between SwiftUI and the underlying `UITextView`s.
  ///
  /// `@FocusState` cannot bind directly to a `UIViewRepresentable`, so the editor
  /// drives first-responder state manually through this object: a paragraph becomes
  /// focused when `focusedParagraphID` equals its own id, and mutations ask for a
  /// cursor placement via `requestedSelection`.
  @MainActor
  @Observable
  public final class FocusCoordinator {
    public var focusedParagraphID: Paragraph.ID?
    /// A selection to apply once focus lands (set by mutations such as split/merge).
    public var requestedSelection: SelectionRequest?

    /// A cursor placement to apply to a specific paragraph after it becomes
    /// first responder.
    public struct SelectionRequest: Equatable {
      public var paragraphID: Paragraph.ID
      public var range: NSRange

      public init(paragraphID: Paragraph.ID, range: NSRange) {
        self.paragraphID = paragraphID
        self.range = range
      }
    }

    public init() {}

    /// Move focus (and optionally place the cursor inside the focused paragraph).
    public func focus(_ id: Paragraph.ID?, selection: NSRange? = nil) {
      focusedParagraphID = id
      if let id, let selection {
        requestedSelection = SelectionRequest(paragraphID: id, range: selection)
      } else {
        requestedSelection = nil
      }
    }

    public func clearSelectionRequest() {
      requestedSelection = nil
    }
  }
#endif

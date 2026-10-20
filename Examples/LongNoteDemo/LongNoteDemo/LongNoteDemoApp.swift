import LongNote
import SwiftUI

@main
struct LongNoteDemoApp: App {
  /// One store shared by the whole app; articles live under
  /// `Documents/Articles/`.
  private let store = FileArticleStore()

  var body: some Scene {
    WindowGroup {
      DraftListView(store: store)
    }
  }
}

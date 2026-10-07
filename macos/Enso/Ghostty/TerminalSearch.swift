import AppKit
import Combine

/// One surface's find-bar state. libghostty does the actual searching —
/// matching, highlighting, scrolling to the selected match — and reports
/// totals back through SEARCH_TOTAL / SEARCH_SELECTED; this object just
/// mirrors that for the bar and pushes needle changes down as
/// `search:<needle>` binding actions.
@MainActor
final class TerminalSearch: ObservableObject {
    /// Whether the find bar is showing for this surface.
    @Published private(set) var isActive = false
    @Published var needle = ""
    /// Match count; nil while libghostty hasn't reported one yet.
    @Published var total: UInt?
    /// Zero-based index of the selected match, nil when none is selected.
    @Published var selected: UInt?
    /// Bumped whenever the bar should (re)take keyboard focus — a second
    /// ⌘F while the bar is already up lands back in the field.
    @Published private(set) var focusRequest = 0

    /// Runs a binding action against the owning surface.
    private let perform: (String) -> Void
    private var needleCancellable: AnyCancellable?

    init(perform: @escaping (String) -> Void) {
        self.perform = perform
    }

    /// START_SEARCH from libghostty (⌘F, ⌘E, or the menu). A non-empty
    /// needle — from "use selection for find" — replaces the current one;
    /// otherwise an opening bar seeds from the system find pasteboard so
    /// the last search carries across tabs and apps, as on any Mac.
    func begin(needle incoming: String?) {
        if let incoming, !incoming.isEmpty {
            needle = incoming
        } else if !isActive, let shared = NSPasteboard(name: .find).string(forType: .string) {
            needle = shared
        }
        if !isActive {
            isActive = true
            observeNeedle()
        }
        focusRequest += 1
    }

    /// END_SEARCH from libghostty (Esc in the terminal, ⇧⌘F), or the bar
    /// closing itself. Idempotent.
    func end() {
        guard isActive else { return }
        isActive = false
        needleCancellable = nil
        total = nil
        selected = nil
        perform("end_search")
    }

    func next() {
        perform("navigate_search:next")
    }

    func previous() {
        perform("navigate_search:previous")
    }

    /// Streams needle edits down to libghostty. Short needles are debounced
    /// (matching upstream Ghostty) so typing the first characters doesn't
    /// kick off a scrollback-wide search for "a" on every keystroke.
    private func observeNeedle() {
        needleCancellable = $needle
            .removeDuplicates()
            .map { needle -> AnyPublisher<String, Never> in
                if needle.isEmpty || needle.count >= 3 {
                    return Just(needle).eraseToAnyPublisher()
                }
                return Just(needle)
                    .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
                    .eraseToAnyPublisher()
            }
            .switchToLatest()
            .sink { [weak self] needle in
                guard let self, self.isActive else { return }
                if needle.isEmpty {
                    self.total = nil
                    self.selected = nil
                } else {
                    let pasteboard = NSPasteboard(name: .find)
                    pasteboard.clearContents()
                    pasteboard.setString(needle, forType: .string)
                }
                self.perform("search:\(needle)")
            }
    }
}

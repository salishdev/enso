import SwiftUI

/// The in-pane find bar: a needle field with a match counter, previous/next
/// buttons, and close. Floats over the top-right corner of its pane's
/// terminal. Return / ⇧Return step through matches; Esc closes and hands
/// the keyboard back to the terminal.
struct TerminalFindBar: View {
    @ObservedObject var search: TerminalSearch
    /// Ends the search and refocuses the pane's terminal.
    let onClose: () -> Void

    @FocusState private var fieldFocused: Bool

    static let size = CGSize(width: 300, height: 40)

    var body: some View {
        HStack(spacing: 2) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.text(0.45))
                TextField("Find", text: $search.needle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($fieldFocused)
                    .onSubmit { search.next() }
                    .onKeyPress(.return, phases: .down) { press in
                        guard press.modifiers.contains(.shift) else { return .ignored }
                        search.previous()
                        return .handled
                    }
                    .onExitCommand(perform: onClose)
                Text(counter)
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(Theme.text(0.45))
                    .fixedSize()
            }
            .padding(.horizontal, 8)
            .frame(maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Theme.ink.opacity(0.07))
            )

            FindBarButton(systemName: "chevron.up", help: "Previous Match (⇧⌘G)") {
                search.previous()
            }
            FindBarButton(systemName: "chevron.down", help: "Next Match (⌘G)") {
                search.next()
            }
            FindBarButton(systemName: "xmark", help: "Close (Esc)", action: onClose)
        }
        .padding(5)
        .frame(width: Self.size.width, height: Self.size.height)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Theme.panel)
                .shadow(color: .black.opacity(0.25), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Theme.ink.opacity(0.09))
        )
        .onAppear { focusField() }
        .onChange(of: search.focusRequest) { focusField() }
    }

    /// "3/12" with a selection, "-/12" before one, "0/0" for no hits;
    /// blank until there's a needle and a reported count.
    private var counter: String {
        guard !search.needle.isEmpty, let total = search.total else { return "" }
        guard let selected = search.selected else { return total == 0 ? "0/0" : "-/\(total)" }
        return "\(selected + 1)/\(total)"
    }

    /// Deferred a turn: on first appearance the hosting view isn't in the
    /// window yet, and on a repeat ⌘F the terminal still holds first
    /// responder from the key event that triggered it.
    private func focusField() {
        DispatchQueue.main.async {
            fieldFocused = true
        }
    }
}

private struct FindBarButton: View {
    let systemName: String
    let help: String
    let action: () -> Void

    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.text(hovered ? 0.85 : 0.55))
                .frame(width: 26, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.ink.opacity(hovered ? 0.08 : 0))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .onHover { hovered = $0 }
    }
}

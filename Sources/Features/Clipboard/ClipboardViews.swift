import AppKit
import DesignSystem
import Services
import SwiftUI

struct ClipboardView: View {
    @ObservedObject var model: ClipboardModel
    @ObservedObject var preferences: Preferences

    var body: some View {
        Group {
            if preferences.clipboardEnabled {
                HistoryView(model: model, paused: preferences.clipboardPaused)
            } else {
                ClipboardOffView { preferences.clipboardEnabled = true }
            }
        }
        .padding(.horizontal, Metrics.contentInset + 4)
        .padding(.vertical, 8)
    }
}

// MARK: - History

private struct HistoryView: View {
    @ObservedObject var model: ClipboardModel
    let paused: Bool
    @FocusState private var searchFocused: Bool

    private static let relative: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Palette.tertiary)
                    TextField(String(localized: "Search clipboard history", comment: "Search placeholder"),
                              text: $model.query)
                        .textFieldStyle(.plain)
                        .font(Typography.body)
                        .foregroundStyle(Palette.primary)
                        .focused($searchFocused)
                        .onSubmit { model.copySelected() }
                        .onKeyPress(.downArrow) { model.moveSelection(by: 1); return .handled }
                        .onKeyPress(.upArrow) { model.moveSelection(by: -1); return .handled }
                }
                .padding(.horizontal, 8)
                .frame(height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Palette.fill))

                Button {
                    model.preferences.clipboardPaused.toggle()
                } label: {
                    Image(systemName: paused ? "play.fill" : "pause.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(paused ? Palette.warning : Palette.secondary)
                }
                .buttonStyle(PressableButtonStyle(diameter: 24))
                .help(paused
                      ? String(localized: "Resume capturing", comment: "Clipboard tooltip")
                      : String(localized: "Pause capturing", comment: "Clipboard tooltip"))

                Button(String(localized: "Clear", comment: "Clipboard: delete all history")) {
                    model.clearAll()
                }
                .buttonStyle(CapsuleButtonStyle())
                .disabled(model.entries.isEmpty)
            }

            let list = model.filtered
            if list.isEmpty {
                Text(emptyMessage)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVStack(spacing: 1) {
                            ForEach(Array(list.enumerated()), id: \.element.id) { index, entry in
                                ClipRow(
                                    entry: entry,
                                    thumbnail: model.thumbnail(for: entry),
                                    age: Self.relative.localizedString(for: entry.createdAt, relativeTo: Date()),
                                    selected: index == model.selectedIndex
                                )
                                .id(entry.id)
                                .onTapGesture { model.copy(entry) }
                                .contextMenu {
                                    Button(String(localized: "Copy", comment: "Clipboard menu")) { model.copy(entry) }
                                    Button(String(localized: "Delete", comment: "Clipboard menu"), role: .destructive) {
                                        model.delete(entry)
                                    }
                                }
                            }
                        }
                    }
                    .onChange(of: model.selectedIndex) { _, index in
                        guard list.indices.contains(index) else { return }
                        withAnimation(Motion.resolved(Motion.content)) {
                            proxy.scrollTo(list[index].id)
                        }
                    }
                }
            }
        }
        .onAppear { searchFocused = true }
    }

    private var emptyMessage: String {
        if !model.query.isEmpty {
            return String(localized: "Nothing matches “\(model.query)”", comment: "Clipboard search empty")
        }
        if paused {
            return String(localized: "Capture is paused", comment: "Clipboard empty while paused")
        }
        return String(localized: "Copy something and it will appear here", comment: "Clipboard empty")
    }
}

private struct ClipRow: View {
    let entry: ClipEntry
    let thumbnail: NSImage?
    let age: String
    let selected: Bool
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 8) {
            icon
                .frame(width: 18, height: 18)
            Text(entry.preview)
                .font(Typography.body)
                .foregroundStyle(Palette.primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text([entry.sourceAppName, age].compactMap { $0 }.joined(separator: " · "))
                .font(Typography.micro)
                .foregroundStyle(Palette.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .frame(height: 26)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(selected ? Palette.selection : (hovering ? Palette.fill : Color.clear))
        )
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isSelected, .isButton] : .isButton)
        .accessibilityHint(Text(String(localized: "Copies this to the clipboard", comment: "Clipboard row hint")))
    }

    @ViewBuilder
    private var icon: some View {
        switch entry.kind {
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            } else {
                Image(systemName: "photo").foregroundStyle(Palette.secondary)
            }
        case .files:
            Image(systemName: "doc").foregroundStyle(Palette.secondary)
        case .text:
            Image(systemName: "text.alignleft").foregroundStyle(Palette.secondary)
        }
    }
}

// MARK: - Off state

private struct ClipboardOffView: View {
    let turnOn: () -> Void

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Palette.fill)
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Palette.tertiary)
            }
            .frame(width: 96, height: 96)

            VStack(alignment: .leading, spacing: 6) {
                Text(String(localized: "Clipboard history is off", comment: "Clipboard off title"))
                    .font(Typography.title)
                    .tracking(Typography.titleTracking)
                    .foregroundStyle(Palette.primary)
                Text(String(
                    localized: "When it's on, \(Branding.appName) checks one counter per second and keeps what you copy — never passwords. History stays on this Mac.",
                    comment: "Clipboard off explanation"
                ))
                .font(Typography.body)
                .foregroundStyle(Palette.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(3)
                Button(String(localized: "Turn on", comment: "Enable clipboard history"), action: turnOn)
                    .buttonStyle(CapsuleButtonStyle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

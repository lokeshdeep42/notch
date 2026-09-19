import AppKit
import DesignSystem
import NotchCore
import SwiftUI

struct ShelfView: View {
    @ObservedObject var model: ShelfModel
    @ObservedObject var thumbnails: ThumbnailCache
    @Environment(\.notchDropTargeted) private var dropTargeted

    var body: some View {
        Group {
            if model.items.isEmpty && model.importing == 0 {
                EmptyShelf(targeted: dropTargeted, error: model.lastError)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    tiles
                    sidebar
                }
            }
        }
        .padding(.horizontal, Metrics.contentInset + 4)
        .padding(.vertical, 10)
        .animation(Motion.resolved(Motion.content), value: model.items.map(\.id))
        .animation(Motion.resolved(Motion.press), value: dropTargeted)
    }

    private var tiles: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(0..<model.importing, id: \.self) { _ in
                    ImportingTile()
                }
                ForEach(model.items) { item in
                    ShelfTile(
                        item: item,
                        image: thumbnails.image(for: item.id, at: model.url(for: item)),
                        selected: model.selection.contains(item.id)
                    )
                    .overlay {
                        ShelfItemInteraction(
                            onClick: { model.click(item.id, modifiers: $0) },
                            onDoubleClick: { model.open([item.id]) },
                            dragPayload: {
                                model.dragSet(startingAt: item.id).map { entry in
                                    (url: model.url(for: entry),
                                     image: thumbnails.image(for: entry.id, at: model.url(for: entry)))
                                }
                            },
                            menu: { menu(for: item) }
                        )
                    }
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
                }
            }
            .padding(.vertical, 2)
        }
        .overlay {
            if dropTargeted {
                RoundedRectangle(cornerRadius: Metrics.cornerMedium, style: .continuous)
                    .strokeBorder(Palette.primary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    .allowsHitTesting(false)
            }
        }
    }

    private var sidebar: some View {
        VStack(alignment: .trailing, spacing: 6) {
            Text(String(localized: "\(model.items.count) items", comment: "Shelf item count"))
                .font(Typography.bodyEmphasis)
                .foregroundStyle(Palette.primary)
            Text(ByteCountFormatter.string(fromByteCount: model.totalBytes, countStyle: .file))
                .font(Typography.digits)
                .foregroundStyle(Palette.tertiary)
            Spacer(minLength: 0)
            if model.items.contains(where: { !$0.isPinned }) {
                Button(String(localized: "Clear", comment: "Shelf: remove all unpinned items")) {
                    model.clearUnpinned()
                }
                .buttonStyle(CapsuleButtonStyle())
                .help(String(localized: "Removes everything except pinned items", comment: "Shelf clear tooltip"))
            }
        }
        .frame(width: 84)
    }

    private func menu(for item: ShelfItem) -> NSMenu {
        if !model.selection.contains(item.id) {
            model.selection = [item.id]
        }
        let ids = model.selection
        let urls = model.items.filter { ids.contains($0.id) }.map { model.url(for: $0) }
        let anyUnpinned = model.items.contains { ids.contains($0.id) && !$0.isPinned }

        let menu = NSMenu()
        menu.addItem(ClosureMenuItem(String(localized: "Open", comment: "Shelf menu"), symbol: "arrow.up.forward.app") {
            model.open(ids)
        })
        menu.addItem(ClosureMenuItem(String(localized: "Show in Finder", comment: "Shelf menu"), symbol: "folder") {
            model.reveal(ids)
        })
        menu.addItem(ClosureMenuItem(String(localized: "Share…", comment: "Shelf menu"), symbol: "square.and.arrow.up") {
            SharePresenter.share(urls)
        })
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(
            anyUnpinned ? String(localized: "Pin", comment: "Shelf menu") : String(localized: "Unpin", comment: "Shelf menu"),
            symbol: anyUnpinned ? "pin" : "pin.slash"
        ) {
            model.togglePin(ids)
        })
        menu.addItem(ClosureMenuItem(String(localized: "Remove", comment: "Shelf menu"), symbol: "trash") {
            model.remove(ids)
        })
        return menu
    }
}

private struct ShelfTile: View {
    let item: ShelfItem
    let image: NSImage
    let selected: Bool

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 52, height: 52)
                .overlay(alignment: .topTrailing) {
                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(3)
                            .background(Circle().fill(Palette.primary))
                            .offset(x: 4, y: -4)
                    }
                }
            Text(item.fileName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(selected ? Palette.primary : Palette.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
                .multilineTextAlignment(.center)
                .frame(width: 70, height: 26, alignment: .top)
        }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: Metrics.cornerSmall + 2, style: .continuous)
                .fill(selected ? Palette.selection : Color.clear)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(item.fileName))
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityHint(Text(String(localized: "Drag out to use, right-click for options", comment: "Shelf tile hint")))
    }
}

private struct ImportingTile: View {
    var body: some View {
        VStack(spacing: 5) {
            ProgressView()
                .controlSize(.small)
                .frame(width: 52, height: 52)
            Text(String(localized: "Copying…", comment: "Shelf: file being copied in"))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Palette.tertiary)
                .frame(width: 70, height: 26, alignment: .top)
        }
        .padding(6)
    }
}

private struct EmptyShelf: View {
    let targeted: Bool
    let error: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Palette.primary.opacity(targeted ? 0.6 : 0.18),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 5])
                )
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(targeted ? Palette.fill : Color.clear)
                )
            HStack(spacing: 14) {
                Image(systemName: targeted ? "tray.and.arrow.down.fill" : "tray.and.arrow.down")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundStyle(targeted ? Palette.primary : Palette.tertiary)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 3) {
                    Text(targeted
                         ? String(localized: "Let go to keep it here", comment: "Shelf drop hint while dragging")
                         : String(localized: "Drop files here", comment: "Shelf empty title"))
                        .font(Typography.bodyEmphasis)
                        .foregroundStyle(Palette.primary)
                    Text(error ?? String(
                        localized: "They're copied in, so moving or deleting the original won't break anything.",
                        comment: "Shelf empty explanation"
                    ))
                    .font(Typography.caption)
                    .foregroundStyle(error == nil ? Palette.secondary : Palette.critical)
                    .lineLimit(2)
                }
            }
            .padding(.horizontal, 20)
        }
        .scaleEffect(targeted ? 1.015 : 1)
    }
}

/// Presents the system share sheet (AirDrop, Mail, Messages…) near the pointer.
@MainActor
enum SharePresenter {
    static func share(_ urls: [URL]) {
        guard !urls.isEmpty, let window = NSApp.windows.first(where: { $0.isVisible && $0.contentView != nil }),
              let view = window.contentView
        else { return }
        let picker = NSSharingServicePicker(items: urls)
        let location = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        let local = view.convert(location, from: nil)
        picker.show(relativeTo: NSRect(x: local.x, y: local.y, width: 1, height: 1), of: view, preferredEdge: .minY)
    }
}

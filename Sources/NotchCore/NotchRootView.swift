import DesignSystem
import Services
import SwiftUI

/// Everything drawn inside one panel window. The window never changes size; this view morphs a
/// single `NotchShape` between collapsed, winged, peeking and open, and clips content to it.
struct NotchRootView: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var hub: NotchHub
    @ObservedObject var preferences: Preferences

    var body: some View {
        let layout = currentLayout
        let shape = NotchShape(
            width: layout.width,
            height: layout.height,
            bottomRadius: layout.radius,
            topFlare: Metrics.topFlareRadius,
            offsetX: layout.offsetX
        )

        shape
            .fill(Palette.panel)
            .overlay(alignment: .top) { content(layout: layout) }
            .clipShape(shape)
            .contentShape(shape)
            .onTapGesture { model.onClick() }
            .shadow(
                color: .black.opacity(model.phase.isExpanded ? 0.45 : 0),
                radius: model.phase.isExpanded ? 18 : 0,
                y: model.phase.isExpanded ? 8 : 0
            )
            .frame(width: model.geometry.windowSize.width, height: model.geometry.windowSize.height, alignment: .top)
            .animation(Motion.resolved(Motion.peek), value: hub.wings?.width)
            .animation(Motion.resolved(Motion.magnet), value: model.magnetStrength)
            .environment(\.notchDropTargeted, model.isDropTargeted)
            .preferredColorScheme(.dark)
    }

    // MARK: Layout

    private struct Layout {
        var width: CGFloat
        var height: CGFloat
        var radius: CGFloat
        var offsetX: CGFloat
        var wingWidth: CGFloat
    }

    private var currentLayout: Layout {
        let notch = model.geometry.notchSize
        switch model.phase {
        case .open, .closing:
            return Layout(
                width: Metrics.expandedWidth,
                height: model.geometry.expandedHeight,
                radius: Metrics.expandedBottomRadius,
                offsetX: 0,
                wingWidth: 0
            )
        case .peek:
            let wing = model.peek?.width ?? 0
            return Layout(
                width: notch.width + wing * 2,
                height: notch.height,
                radius: Metrics.collapsedBottomRadius,
                offsetX: 0,
                wingWidth: wing
            )
        case .closed, .pending, .suppressed:
            let wing = hub.wings?.width ?? 0
            // Pending: grow a few points immediately, so the hover is acknowledged on the same
            // frame even though opening waits for the delay or a confirmed intent.
            let acknowledge: CGFloat = model.phase == .pending ? 1 : 0
            let pull = model.magnetStrength
            return Layout(
                width: notch.width + wing * 2 + acknowledge * 12 + pull * 36,
                height: notch.height + acknowledge * 3 + pull * 12,
                radius: Metrics.collapsedBottomRadius + pull * 4,
                offsetX: model.magnetLean,
                wingWidth: wing
            )
        }
    }

    // MARK: Content

    @ViewBuilder
    private func content(layout: Layout) -> some View {
        let notch = model.geometry.notchSize
        ZStack(alignment: .top) {
            if model.phase.isExpanded {
                ExpandedPanel(model: model, hub: hub, preferences: preferences)
                    .frame(width: Metrics.expandedWidth, height: model.geometry.expandedHeight)
                    .transition(Motion.reduceMotion ? .opacity : .materialize)
            } else if model.phase == .peek, let peek = model.peek {
                WingsRow(leading: peek.leading, trailing: peek.trailing,
                         notchWidth: notch.width, wingWidth: peek.width, height: notch.height)
                    .id(peek.id)
                    .transition(.opacity.animation(Motion.content.delay(Motion.contentStagger)))
            } else if let wings = hub.wings, model.phase != .suppressed {
                WingsRow(leading: wings.leading, trailing: wings.trailing,
                         notchWidth: notch.width, wingWidth: wings.width, height: notch.height)
                    .offset(x: layout.offsetX)
                    .transition(.opacity)
            }
        }
        .frame(width: layout.width, alignment: .top)
    }
}

/// Static content on either side of the notch while collapsed or peeking.
private struct WingsRow: View {
    let leading: AnyView
    let trailing: AnyView
    let notchWidth: CGFloat
    let wingWidth: CGFloat
    let height: CGFloat

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: wingWidth, height: height)
            Color.clear
                .frame(width: notchWidth, height: height)
            trailing
                .frame(width: wingWidth, height: height)
        }
        .frame(height: height)
    }
}

// MARK: - Open panel

private struct ExpandedPanel: View {
    @ObservedObject var model: PanelModel
    @ObservedObject var hub: NotchHub
    @ObservedObject var preferences: Preferences
    @Namespace private var tabNamespace

    var body: some View {
        let notch = model.geometry.notchSize
        let sideWidth = max((Metrics.expandedWidth - notch.width) / 2, 0)

        VStack(spacing: 0) {
            // Row beside the camera housing: tabs on the left, accessory on the right.
            HStack(spacing: 0) {
                tabBar
                    .frame(width: sideWidth, alignment: .leading)
                Color.clear
                    .frame(width: notch.width)
                headerAccessory
                    .frame(width: sideWidth, alignment: .trailing)
            }
            .frame(height: notch.height)

            moduleContent
                .frame(width: Metrics.expandedWidth, height: Metrics.contentHeight)

            footer
                .frame(height: Metrics.footerHeight)
        }
        .onExitCommand { model.onCollapse() }
    }

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(hub.enabledModuleRefs) { ref in
                let module = ref.module
                let selected = module.id == hub.selectedModule?.id
                Button {
                    hub.select(moduleID: module.id)
                } label: {
                    Image(systemName: module.symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(selected ? Palette.primary : Palette.tertiary)
                        .frame(width: 30, height: 22)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Palette.selection)
                                    .matchedGeometryEffect(id: "tab", in: tabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help(module.title)
                .accessibilityLabel(Text(module.title))
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(.leading, Metrics.contentInset + 4)
        .animation(Motion.resolved(Motion.content), value: hub.selectedModuleID)
    }

    @ViewBuilder
    private var headerAccessory: some View {
        HStack(spacing: 8) {
            ForEach(hub.enabledModuleRefs) { ref in
                if let accessory = ref.module.makeHeaderAccessory() {
                    accessory
                }
            }
        }
        .padding(.trailing, Metrics.contentInset + 4)
    }

    @ViewBuilder
    private var moduleContent: some View {
        if let module = hub.selectedModule {
            module.makeExpandedView()
                .id(module.id)
                .transition(.opacity.animation(Motion.resolved(Motion.content)))
        } else {
            VStack(spacing: 6) {
                Text(String(localized: "Everything is switched off", comment: "Empty panel title"))
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(Palette.primary)
                Text(String(localized: "Turn on a module in Settings.", comment: "Empty panel hint"))
                    .font(Typography.caption)
                    .foregroundStyle(Palette.secondary)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if let receipt = model.receipt {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Palette.positive.opacity(0.8))
                Text(receipt.summary)
                    .font(Typography.micro)
                    .foregroundStyle(Palette.tertiary)
                    .help(String(
                        localized: "What \(Branding.appName) has cost your Mac since it launched, read from the kernel — not estimated.",
                        comment: "Cost receipt tooltip"
                    ))
            }
            Spacer(minLength: 8)
            if preferences.debugOverlay {
                DebugOverlay(phase: model.phase, displayID: model.displayID)
            }
            Button {
                hub.openSettings?()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.tertiary)
            }
            .buttonStyle(PressableButtonStyle(diameter: 20))
            .help(String(localized: "Settings", comment: "Settings button tooltip"))
            .accessibilityLabel(Text(String(localized: "Settings", comment: "Settings button")))
        }
        .padding(.horizontal, Metrics.contentInset + 4)
    }
}

// MARK: - Transitions

private struct Materialize: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        content
            .opacity(active ? 0 : 1)
            .blur(radius: active ? 6 : 0)
            .scaleEffect(active ? 0.96 : 1, anchor: .top)
    }
}

extension AnyTransition {
    /// Content arrives like a material settling into place: blur, scale and opacity together,
    /// slightly behind the shape. Leaves quickly so collapse never feels sticky.
    static var materialize: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: Materialize(active: true), identity: Materialize(active: false))
                .animation(Motion.content.delay(Motion.contentStagger)),
            removal: .opacity.animation(.easeOut(duration: 0.1))
        )
    }
}

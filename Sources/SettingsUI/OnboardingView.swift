import DesignSystem
import NotchCore
import Services
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var preferences: Preferences
    let onFinish: () -> Void

    @State private var page = 0
    @State private var forward = true
    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Group {
                    switch page {
                    case 0: WelcomePage()
                    case 1: ModulesPage(preferences: preferences)
                    default: TryItPage()
                    }
                }
                .id(page)
                // Pages leave the way they came: forward slides left, back slides right.
                .transition(Motion.reduceMotion ? .opacity : .asymmetric(
                    insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: forward ? .leading : .trailing).combined(with: .opacity)
                ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()

            HStack {
                if page < pageCount - 1 {
                    Button(String(localized: "Skip", comment: "Onboarding"), action: onFinish)
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                } else if page > 0 {
                    Button(String(localized: "Back", comment: "Onboarding")) { go(to: page - 1) }
                        .buttonStyle(.borderless)
                }
                Spacer()
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { index in
                        Circle()
                            .fill(index == page ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                }
                .accessibilityHidden(true)
                Spacer()
                Button(page == pageCount - 1
                       ? String(localized: "Done", comment: "Onboarding")
                       : String(localized: "Continue", comment: "Onboarding")) {
                    if page == pageCount - 1 { onFinish() } else { go(to: page + 1) }
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
        }
        .frame(width: 520, height: 400)
    }

    private func go(to target: Int) {
        forward = target > page
        withAnimation(Motion.resolved(Motion.content)) {
            page = target
        }
    }
}

// MARK: - Pages

private struct WelcomePage: View {
    @State private var open = false

    var body: some View {
        VStack(spacing: 18) {
            // The real panel shape, opening once — a preview of the actual interaction.
            ZStack(alignment: .top) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.16))
                    .frame(width: 300, height: 110)
                NotchShape(
                    width: open ? 240 : 80,
                    height: open ? 72 : 18,
                    bottomRadius: open ? 18 : 7,
                    topFlare: 4
                )
                .fill(Color.black)
                .frame(width: 300, height: 110)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.top, 36)
            .accessibilityHidden(true)

            Text(String(localized: "Your notch, put to work", comment: "Onboarding title"))
                .font(.system(size: 24, weight: .semibold))
                .tracking(-0.5)
            Text(String(localized: "Hover the notch to open \(Branding.appName). Move away and it disappears. No Dock icon, no clutter.", comment: "Onboarding body"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Label(String(localized: "It shows you exactly what it costs your Mac. Closed, that's effectively nothing.", comment: "Onboarding promise"),
                  systemImage: "leaf.fill")
                .font(.callout)
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 32)
        .onAppear {
            withAnimation(Motion.resolved(Motion.expand).delay(0.4)) { open = true }
        }
    }
}

private struct ModulesPage: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(String(localized: "Choose what lives there", comment: "Onboarding title"))
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.4)
                .padding(.top, 36)
            row(symbol: "music.note",
                title: String(localized: "Now Playing", comment: "Module"),
                detail: String(localized: "Artwork, track and controls for whatever is playing.", comment: "Onboarding module detail"),
                isOn: $preferences.nowPlayingEnabled)
            row(symbol: "tray",
                title: String(localized: "Shelf", comment: "Module"),
                detail: String(localized: "Drag files toward the notch to park them; drag them out later.", comment: "Onboarding module detail"),
                isOn: $preferences.shelfEnabled)
            row(symbol: "doc.on.clipboard",
                title: String(localized: "Clipboard history", comment: "Module"),
                detail: String(localized: "Off until you want it. Never keeps passwords; stays on this Mac.", comment: "Onboarding module detail"),
                isOn: $preferences.clipboardEnabled)
            Text(String(localized: "You can change these any time in Settings.", comment: "Onboarding footnote"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func row(symbol: String, title: String, detail: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            Toggle(title, isOn: isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

private struct TryItPage: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cursorarrow.motionlines")
                .font(.system(size: 40, weight: .regular))
                .padding(.top, 44)
                .accessibilityHidden(true)
            Text(String(localized: "Try it now", comment: "Onboarding title"))
                .font(.system(size: 24, weight: .semibold))
                .tracking(-0.5)
            VStack(alignment: .leading, spacing: 10) {
                Label(String(localized: "Move the pointer into the notch and let it settle.", comment: "Onboarding step"),
                      systemImage: "1.circle")
                Label(String(localized: "Drag any file toward the notch to put it on the shelf.", comment: "Onboarding step"),
                      systemImage: "2.circle")
                Label(String(localized: "Settings live in the menu bar icon.", comment: "Onboarding step"),
                      systemImage: "3.circle")
            }
            .font(.body)
            Text(String(localized: "On displays without a notch, \(Branding.appName) draws a small pill at the top centre instead.", comment: "Onboarding footnote"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
        }
        .padding(.horizontal, 32)
    }
}

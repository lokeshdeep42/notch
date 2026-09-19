import DesignSystem
import SwiftUI

struct BatteryView: View {
    @ObservedObject var monitor: PowerMonitor

    var body: some View {
        HStack(spacing: 24) {
            if let snapshot = monitor.snapshot {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(snapshot.percent)%")
                        .font(Typography.display)
                        .tracking(Typography.displayTracking)
                        .foregroundStyle(Palette.primary)
                    Text(status(snapshot))
                        .font(Typography.body)
                        .foregroundStyle(Palette.secondary)
                }
                BatteryMeter(percent: snapshot.percent, charging: snapshot.isCharging)
                    .frame(width: 150, height: 44)
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: 6) {
                    stat(String(localized: "Health", comment: "Battery health label"),
                         value: monitor.health?.healthPercent.map { "\($0)%" })
                    stat(String(localized: "Cycles", comment: "Battery cycle count label"),
                         value: monitor.health?.cycleCount.map { "\($0)" })
                }
            } else {
                Text(String(localized: "No battery information", comment: "Battery unavailable"))
                    .font(Typography.body)
                    .foregroundStyle(Palette.secondary)
            }
        }
        .padding(.horizontal, Metrics.contentInset + 8)
        .frame(maxHeight: .infinity)
    }

    private func stat(_ label: String, value: String?) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.tertiary)
            Text(value ?? "—")
                .font(Typography.digits)
                .foregroundStyle(Palette.primary)
        }
    }

    private func status(_ snapshot: PowerSnapshot) -> String {
        if snapshot.isCharging {
            if let minutes = snapshot.minutesToFull {
                return String(localized: "Charging — full in \(Self.duration(minutes))", comment: "Battery status")
            }
            return String(localized: "Charging", comment: "Battery status")
        }
        if snapshot.isOnAC {
            return snapshot.isCharged
                ? String(localized: "Fully charged", comment: "Battery status")
                : String(localized: "Plugged in, not charging", comment: "Battery status")
        }
        if let minutes = snapshot.minutesToEmpty {
            return String(localized: "\(Self.duration(minutes)) remaining", comment: "Battery status")
        }
        return String(localized: "On battery", comment: "Battery status")
    }

    static func duration(_ minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = minutes >= 60 ? [.hour, .minute] : [.minute]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
    }
}

private struct BatteryMeter: View {
    let percent: Int
    let charging: Bool

    var body: some View {
        let fill: Color = percent <= 10 ? Palette.critical : (percent <= 20 ? Palette.warning : Palette.positive)
        HStack(spacing: 3) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Palette.tertiary, lineWidth: 1.5)
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(fill)
                        .frame(width: max((proxy.size.width) * CGFloat(percent) / 100, 6))
                }
                .padding(4)
                if charging {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.black.opacity(0.7))
                        .frame(maxWidth: .infinity)
                }
            }
            RoundedRectangle(cornerRadius: 2)
                .fill(Palette.tertiary)
                .frame(width: 4, height: 14)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(localized: "Battery \(percent) percent", comment: "Battery meter")))
    }
}

struct BatteryBadge: View {
    @ObservedObject var monitor: PowerMonitor

    var body: some View {
        if let snapshot = monitor.snapshot {
            HStack(spacing: 4) {
                PercentText(percent: snapshot.percent)
                BatteryGlyph(snapshot: snapshot)
            }
        }
    }
}

struct BatteryGlyph: View {
    let snapshot: PowerSnapshot

    var body: some View {
        Image(systemName: snapshot.symbolName)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(snapshot.percent <= 10 && !snapshot.isOnAC ? Palette.critical : Palette.primary)
    }
}

struct PercentText: View {
    let percent: Int

    var body: some View {
        Text(verbatim: "\(percent)%")
            .font(Typography.digits)
            .foregroundStyle(Palette.secondary)
    }
}

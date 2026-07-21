import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Configuration (editable on the widget itself, long-press → Edit)

struct XPConfigIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "OSRS Daily XP"
    static var description = IntentDescription("Track the XP you've gained today toward a daily target.")

    @Parameter(title: "RuneScape name")
    var username: String?

    @Parameter(title: "Daily XP target", default: 1_000_000)
    var target: Int
}

// MARK: - Timeline entry

struct XPEntry: TimelineEntry {
    let date: Date
    let username: String
    let gainedToday: Int
    let target: Int
    let placeholder: Bool
    let message: String?

    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(gainedToday) / Double(target))
    }
    var reached: Bool { gainedToday >= target && target > 0 }
    var remaining: Int { max(0, target - gainedToday) }
}

// MARK: - Provider

struct XPProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> XPEntry {
        XPEntry(date: .now, username: "Zezima", gainedToday: 425_000, target: 1_000_000, placeholder: true, message: nil)
    }

    func snapshot(for configuration: XPConfigIntent, in context: Context) async -> XPEntry {
        await loadEntry(for: configuration)
    }

    func timeline(for configuration: XPConfigIntent, in context: Context) async -> Timeline<XPEntry> {
        let entry = await loadEntry(for: configuration)
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now.addingTimeInterval(1800)
        return Timeline(entries: [entry], policy: .after(next))
    }

    private func loadEntry(for configuration: XPConfigIntent) async -> XPEntry {
        let target = max(1, configuration.target)
        let name = configuration.username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !name.isEmpty else {
            return XPEntry(date: .now, username: "", gainedToday: 0, target: target, placeholder: false, message: "Long-press to set your name")
        }
        do {
            // Calendar-day gains (local midnight → now) to match WOM's daily XP graph.
            let gains = try await WOMService.shared.gainsToday(name)
            let gained = max(0, gains.data.skills["overall"]?.experience.gained ?? 0)
            return XPEntry(date: .now, username: name, gainedToday: gained, target: target, placeholder: false, message: nil)
        } catch {
            return XPEntry(date: .now, username: name, gainedToday: 0, target: target, placeholder: false, message: "Couldn't load")
        }
    }
}

// MARK: - Views

struct XPWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: XPEntry

    var body: some View {
        switch family {
        case .systemSmall: smallView
        default: mediumView
        }
    }

    private var smallView: some View {
        VStack(spacing: 8) {
            ring(size: 84, line: 9)
            if let message = entry.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(entry.username)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
    }

    private var mediumView: some View {
        HStack(spacing: 16) {
            ring(size: 96, line: 11)
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.username.isEmpty ? "OSRS Daily XP" : entry.username)
                    .font(.headline)
                    .lineLimit(1)
                if let message = entry.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Label("\(Fmt.full(entry.gainedToday)) XP today", systemImage: "bolt.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    Text("Target \(Fmt.short(entry.target))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if entry.reached {
                        Label("Target reached", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.green)
                    } else {
                        Text("\(Fmt.short(entry.remaining)) to go")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private func ring(size: CGFloat, line: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: line)
            Circle()
                .trim(from: 0, to: entry.progress)
                .stroke(
                    entry.reached ? Color.green : Color.accentColor,
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(Int((entry.progress * 100).rounded()))%")
                    .font(.system(size: size * 0.24, weight: .bold))
                    .monospacedDigit()
                Text(Fmt.short(entry.gainedToday))
                    .font(.system(size: size * 0.15))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Widget

struct XPWidget: Widget {
    let kind = "XPWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: XPConfigIntent.self, provider: XPProvider()) { entry in
            XPWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("OSRS Daily XP")
        .description("XP gained today toward your target.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Formatting (self-contained so the widget target needs no extra files)

enum Fmt {
    static func short(_ n: Int) -> String {
        switch n {
        case 1_000_000...: return String(format: "%.1fM", Double(n) / 1_000_000)
        case 1_000...: return String(format: "%.0fK", Double(n) / 1_000)
        default: return "\(n)"
        }
    }
    static func full(_ n: Int) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }
}

#Preview(as: .systemMedium) {
    XPWidget()
} timeline: {
    XPEntry(date: .now, username: "Zezima", gainedToday: 425_000, target: 1_000_000, placeholder: false, message: nil)
    XPEntry(date: .now, username: "Zezima", gainedToday: 1_050_000, target: 1_000_000, placeholder: false, message: nil)
}

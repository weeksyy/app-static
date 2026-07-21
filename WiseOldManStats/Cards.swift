import SwiftUI

// MARK: - Shared container

struct Card<Content: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).font(.headline)
                Spacer()
                if let subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Summary

struct SummaryCard: View {
    let player: PlayerDetails
    let gains: PlayerGains?
    let period: GainsPeriod

    private var overall: SkillDetail? { player.latestSnapshot?.data.skills["overall"] }
    private var overallGain: Int { gains?.data.skills["overall"]?.experience.gained ?? 0 }

    var body: some View {
        Card(title: player.displayName, subtitle: player.type.capitalized) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                Metric(label: "Combat", value: "\(player.combatLevel)")
                Metric(label: "Total level", value: (overall?.level ?? 0).grouped)
                Metric(label: "Total XP", value: (overall?.experience ?? player.exp).grouped)
                Metric(label: "EHP", value: player.ehp.oneDecimal)
                Metric(label: "EHB", value: player.ehb.oneDecimal)
                Metric(label: "\(period.label) XP", value: overallGain.gainDisplay, highlight: overallGain > 0)
            }

            if let window = gainsWindow {
                Text(window)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var gainsWindow: String? {
        guard let start = gains?.startsAt, let end = gains?.endsAt,
              let s = ISO8601.date(start), let e = ISO8601.date(end) else { return nil }
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return "Gains: \(df.string(from: s)) → \(df.string(from: e))"
    }
}

private struct Metric: View {
    let label: String
    let value: String
    var highlight: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(highlight ? Color.green : Color.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Skills

struct SkillsCard: View {
    let player: PlayerDetails
    let gains: PlayerGains?

    var body: some View {
        Card(title: "Skills") {
            VStack(spacing: 0) {
                HeaderRow(columns: ["Level", "XP", "Rank", "Gained"])
                ForEach(Metrics.skillOrder, id: \.self) { key in
                    if let skill = player.latestSnapshot?.data.skills[key] {
                        let gained = gains?.data.skills[key]?.experience.gained ?? 0
                        StatRow(
                            name: Metrics.name(key),
                            columns: [
                                "\(skill.level)",
                                skill.experience.grouped,
                                skill.rank.rankDisplay,
                                gained.gainDisplay
                            ],
                            gainHighlight: gained > 0
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Bosses

struct BossesCard: View {
    let player: PlayerDetails
    let gains: PlayerGains?

    private var bosses: [BossDetail] {
        (player.latestSnapshot?.data.bosses.values.filter { $0.kills > 0 } ?? [])
            .sorted { $0.kills > $1.kills }
    }

    var body: some View {
        Card(title: "Bosses", subtitle: bosses.isEmpty ? nil : "\(bosses.count) tracked") {
            if bosses.isEmpty {
                EmptyRow(text: "No boss kills recorded on the hiscores.")
            } else {
                VStack(spacing: 0) {
                    HeaderRow(columns: ["Kills", "Rank", "Gained"])
                    ForEach(bosses, id: \.metric) { boss in
                        let gained = gains?.data.bosses[boss.metric]?.kills.gained ?? 0
                        StatRow(
                            name: Metrics.name(boss.metric),
                            columns: [
                                boss.kills.grouped,
                                boss.rank.rankDisplay,
                                gained.gainDisplay
                            ],
                            gainHighlight: gained > 0
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Activities

struct ActivitiesCard: View {
    let player: PlayerDetails
    let gains: PlayerGains?

    private var activities: [ActivityDetail] {
        (player.latestSnapshot?.data.activities.values.filter { $0.score > 0 } ?? [])
            .sorted { $0.score > $1.score }
    }

    var body: some View {
        Card(title: "Activities & Clues") {
            if activities.isEmpty {
                EmptyRow(text: "No activity scores recorded.")
            } else {
                VStack(spacing: 0) {
                    HeaderRow(columns: ["Score", "Rank", "Gained"])
                    ForEach(activities, id: \.metric) { act in
                        let gained = gains?.data.activities[act.metric]?.score.gained ?? 0
                        StatRow(
                            name: Metrics.name(act.metric),
                            columns: [
                                act.score.grouped,
                                act.rank.rankDisplay,
                                gained.gainDisplay
                            ],
                            gainHighlight: gained > 0
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Row building blocks

private struct HeaderRow: View {
    let columns: [String]
    var body: some View {
        HStack(spacing: 8) {
            Text("").frame(maxWidth: .infinity, alignment: .leading)
            ForEach(columns, id: \.self) { c in
                Text(c)
                    .frame(width: 74, alignment: .trailing)
            }
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
    }
}

private struct StatRow: View {
    let name: String
    let columns: [String]
    var gainHighlight: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(name)
                .font(.subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(Array(columns.enumerated()), id: \.offset) { idx, value in
                Text(value)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(isGainColumn(idx) && gainHighlight ? Color.green : Color.primary)
                    .frame(width: 74, alignment: .trailing)
            }
        }
        .padding(.vertical, 7)
        .overlay(Divider(), alignment: .bottom)
    }

    private func isGainColumn(_ idx: Int) -> Bool { idx == columns.count - 1 }
}

private struct EmptyRow: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
    }
}

// MARK: - Date parsing

enum ISO8601 {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()

    static func date(_ string: String) -> Date? {
        withFraction.date(from: string) ?? plain.date(from: string)
    }
}

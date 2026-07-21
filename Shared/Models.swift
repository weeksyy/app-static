import Foundation

// MARK: - Player details (GET /players/{username})

struct PlayerDetails: Codable, Identifiable {
    let id: Int
    let username: String
    let displayName: String
    let type: String
    let build: String
    let combatLevel: Int
    let exp: Int
    let ehp: Double
    let ehb: Double
    let ttm: Double?
    let updatedAt: String?
    let lastChangedAt: String?
    let latestSnapshot: Snapshot?
}

struct Snapshot: Codable {
    let createdAt: String?
    let data: SnapshotData
}

struct SnapshotData: Codable {
    let skills: [String: SkillDetail]
    let bosses: [String: BossDetail]
    let activities: [String: ActivityDetail]
}

struct SkillDetail: Codable {
    let metric: String
    let experience: Int
    let level: Int
    let rank: Int
    let ehp: Double?
}

struct BossDetail: Codable {
    let metric: String
    let kills: Int
    let rank: Int
    let ehb: Double?
}

struct ActivityDetail: Codable {
    let metric: String
    let score: Int
    let rank: Int
}

// MARK: - Gains (GET /players/{username}/gained?period=…)

struct PlayerGains: Codable {
    let startsAt: String?
    let endsAt: String?
    let data: GainsData
}

struct GainsData: Codable {
    let skills: [String: SkillGain]
    let bosses: [String: BossGain]
    let activities: [String: ActivityGain]
}

/// A gained/start/end triple. WOM returns whole numbers for XP, kills and scores.
struct GainDelta: Codable {
    let gained: Int
    let start: Int
    let end: Int
}

struct SkillGain: Codable {
    let metric: String
    let experience: GainDelta
    let level: GainDelta
    let rank: GainDelta
}

struct BossGain: Codable {
    let metric: String
    let kills: GainDelta
    let rank: GainDelta
}

struct ActivityGain: Codable {
    let metric: String
    let score: GainDelta
    let rank: GainDelta
}

// MARK: - Error envelope (WOM returns { "message": "..." } on errors)

struct WOMErrorBody: Codable {
    let message: String
}

import Foundation

/// Display helpers for Wise Old Man metric keys.
enum Metrics {

    /// Skills in the in-game hiscores layout order (excluding "overall",
    /// which is shown separately in the summary).
    static let skillOrder: [String] = [
        "attack", "hitpoints", "mining",
        "strength", "agility", "smithing",
        "defence", "herblore", "fishing",
        "ranged", "thieving", "cooking",
        "prayer", "crafting", "firemaking",
        "magic", "fletching", "woodcutting",
        "runecrafting", "slayer", "farming",
        "construction", "hunter"
    ]

    /// Special-cased pretty names; everything else falls back to title-casing
    /// the snake_case key.
    private static let special: [String: String] = [
        "runecrafting": "Runecraft",
        "clue_scrolls_all": "Clue Scrolls (All)",
        "clue_scrolls_beginner": "Clues (Beginner)",
        "clue_scrolls_easy": "Clues (Easy)",
        "clue_scrolls_medium": "Clues (Medium)",
        "clue_scrolls_hard": "Clues (Hard)",
        "clue_scrolls_elite": "Clues (Elite)",
        "clue_scrolls_master": "Clues (Master)",
        "last_man_standing": "Last Man Standing",
        "pvp_arena": "PvP Arena",
        "soul_wars_zeal": "Soul Wars Zeal",
        "guardians_of_the_rift": "Guardians of the Rift",
        "colosseum_glory": "Colosseum Glory",
        "bounty_hunter_hunter": "Bounty Hunter (Hunter)",
        "bounty_hunter_rogue": "Bounty Hunter (Rogue)",
        "chambers_of_xeric": "Chambers of Xeric",
        "chambers_of_xeric_challenge_mode": "Chambers of Xeric (CM)",
        "theatre_of_blood": "Theatre of Blood",
        "theatre_of_blood_hard_mode": "Theatre of Blood (HM)",
        "tombs_of_amascut": "Tombs of Amascut",
        "tombs_of_amascut_expert": "Tombs of Amascut (Expert)",
        "tzkal_zuk": "TzKal-Zuk",
        "tztok_jad": "TzTok-Jad",
        "kril_tsutsaroth": "K'ril Tsutsaroth",
        "dagannoth_prime": "Dagannoth Prime",
        "dagannoth_rex": "Dagannoth Rex",
        "dagannoth_supreme": "Dagannoth Supreme",
        "the_gauntlet": "The Gauntlet",
        "the_corrupted_gauntlet": "The Corrupted Gauntlet",
        "the_leviathan": "The Leviathan",
        "the_whisperer": "The Whisperer",
        "the_hueycoatl": "The Hueycoatl",
        "the_royal_titans": "The Royal Titans",
        "phantom_muspah": "Phantom Muspah",
        "grotesque_guardians": "Grotesque Guardians",
        "thermonuclear_smoke_devil": "Thermonuclear Smoke Devil"
    ]

    static func name(_ key: String) -> String {
        if let s = special[key] { return s }
        return key
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

// MARK: - Number formatting

extension Int {
    /// 1234567 → "1,234,567"
    var grouped: String {
        Int.groupedFormatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Rank shown as "—" when unranked (-1).
    var rankDisplay: String {
        self < 0 ? "—" : grouped
    }

    /// Signed gain: 0 → "—", positive → "+1,234".
    var gainDisplay: String {
        if self == 0 { return "—" }
        let sign = self > 0 ? "+" : "−"
        return sign + abs(self).grouped
    }

    private static let groupedFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()
}

extension Double {
    var oneDecimal: String {
        String(format: "%.1f", self)
    }
}

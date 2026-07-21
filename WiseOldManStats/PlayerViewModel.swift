import Foundation

/// Selectable gains windows offered in the UI.
enum GainsPeriod: String, CaseIterable, Identifiable {
    case day, week, month, year
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var username = ""
    @Published var period: GainsPeriod = .day
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var player: PlayerDetails?
    @Published var gains: PlayerGains?
    @Published var recentSearches: [String] = []

    private let service = WOMService.shared
    private let recentKey = "recentSearches"
    private let recentLimit = 8

    init() {
        recentSearches = UserDefaults.standard.stringArray(forKey: recentKey) ?? []
    }

    var canSearch: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
    }

    // MARK: - Recent searches

    private func remember(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var list = recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
        list.insert(trimmed, at: 0)
        recentSearches = Array(list.prefix(recentLimit))
        UserDefaults.standard.set(recentSearches, forKey: recentKey)
    }

    func selectRecent(_ name: String) {
        username = name
        Task { await lookup() }
    }

    func clearRecents() {
        recentSearches = []
        UserDefaults.standard.removeObject(forKey: recentKey)
    }

    /// Fetch details and gains together.
    func lookup() async {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            async let detailsTask = service.player(name)
            async let gainsTask = fetchGains(name)
            let (details, gains) = try await (detailsTask, gainsTask)
            self.player = details
            self.gains = gains
            remember(details.displayName)
        } catch let error as WOMError {
            self.errorMessage = error.errorDescription
            // Keep any previously loaded player visible on refresh failures.
            if case .notFound = error {
                self.player = nil
                self.gains = nil
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    /// Re-fetch just the gains for the currently selected period.
    func refreshGains() async {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, player != nil else { return }
        self.gains = await fetchGains(name)
    }

    /// Fetch gains for the selected period. "Day" uses the current calendar day
    /// (local midnight → now) to match WOM's daily XP graph; other periods use
    /// the rolling window. Never throws — returns nil if gains are unavailable
    /// (e.g. no snapshot recorded yet today), so the stats still load.
    private func fetchGains(_ name: String) async -> PlayerGains? {
        do {
            if period == .day {
                return try await service.gainsToday(name)
            }
            return try await service.gains(name, period: period.rawValue)
        } catch {
            return nil
        }
    }

    /// Track a new player (or pull a fresh snapshot from the hiscores), then
    /// reload everything.
    func update() async {
        let name = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        isLoading = true
        errorMessage = nil

        do {
            _ = try await service.update(name)
        } catch let error as WOMError {
            self.errorMessage = error.errorDescription
            isLoading = false
            return
        } catch {
            self.errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        isLoading = false
        await lookup()
    }
}

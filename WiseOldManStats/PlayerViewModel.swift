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

    private let service = WOMService.shared

    var canSearch: Bool {
        !username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isLoading
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
            async let gainsTask = service.gains(name, period: period.rawValue)
            let (details, gains) = try await (detailsTask, gainsTask)
            self.player = details
            self.gains = gains
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
        do {
            self.gains = try await service.gains(name, period: period.rawValue)
        } catch let error as WOMError {
            self.errorMessage = error.errorDescription
        } catch {
            self.errorMessage = error.localizedDescription
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

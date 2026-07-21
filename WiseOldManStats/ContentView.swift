import SwiftUI

struct ContentView: View {
    @StateObject private var vm = PlayerViewModel()
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    searchBar

                    if let error = vm.errorMessage {
                        ErrorBanner(message: error)
                    }

                    if vm.isLoading && vm.player == nil {
                        ProgressView("Loading…")
                            .padding(.top, 60)
                    } else if let player = vm.player {
                        SummaryCard(player: player, gains: vm.gains, period: vm.period)
                        SkillsCard(player: player, gains: vm.gains)
                        BossesCard(player: player, gains: vm.gains)
                        ActivitiesCard(player: player, gains: vm.gains)
                    } else {
                        EmptyState()
                            .padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("OSRS Stats")
            .scrollDismissesKeyboard(.interactively)
        }
    }

    private var searchBar: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("RuneScape name", text: $vm.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searchFocused)
                    .onSubmit { runLookup() }
                if !vm.username.isEmpty {
                    Button {
                        vm.username = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 10) {
                Picker("Period", selection: $vm.period) {
                    ForEach(GainsPeriod.allCases) { p in
                        Text(p.label).tag(p)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: vm.period) { _, _ in
                    Task { await vm.refreshGains() }
                }
            }

            HStack(spacing: 10) {
                Button(action: runLookup) {
                    Label("Look up", systemImage: "arrow.right.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.canSearch)

                Button {
                    searchFocused = false
                    Task { await vm.update() }
                } label: {
                    Label("Update", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(!vm.canSearch)
            }

            if vm.isLoading && vm.player != nil {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    private func runLookup() {
        searchFocused = false
        Task { await vm.lookup() }
    }
}

// MARK: - Empty / error states

private struct EmptyState: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("🧙")
                .font(.system(size: 56))
            Text("Look up any player")
                .font(.headline)
            Text("Enter a RuneScape name to see current stats, daily XP gains and boss kill counts — all from Wise Old Man.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 24)
    }
}

private struct ErrorBanner: View {
    let message: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ContentView()
}

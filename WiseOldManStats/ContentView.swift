import SwiftUI

struct ContentView: View {
    @StateObject private var vm = PlayerViewModel()
    @FocusState private var searchFocused: Bool
    @AppStorage("dailyXPTarget") private var dailyTarget: Int = 1_000_000
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    searchBar

                    if !vm.recentSearches.isEmpty {
                        RecentSearches(names: vm.recentSearches,
                                       onSelect: { name in
                                           searchFocused = false
                                           vm.selectRecent(name)
                                       },
                                       onClear: vm.clearRecents)
                    }

                    if let error = vm.errorMessage {
                        ErrorBanner(message: error)
                    }

                    if vm.isLoading && vm.player == nil {
                        ProgressView("Loading…")
                            .padding(.top, 60)
                    } else if let player = vm.player {
                        SummaryCard(player: player, gains: vm.gains, period: vm.period, dailyTarget: dailyTarget)
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
            .refreshable { await vm.lookup() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "target")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                TargetSettingsSheet(target: $dailyTarget)
            }
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

            Picker("Period", selection: $vm.period) {
                ForEach(GainsPeriod.allCases) { p in
                    Text(p.label).tag(p)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: vm.period) { _, _ in
                Task { await vm.refreshGains() }
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

// MARK: - Recent searches

private struct RecentSearches: View {
    let names: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear", action: onClear)
                    .font(.caption)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(names, id: \.self) { name in
                        Button {
                            onSelect(name)
                        } label: {
                            Text(name)
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color(.secondarySystemGroupedBackground))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

// MARK: - Daily target settings

private struct TargetSettingsSheet: View {
    @Binding var target: Int
    @Environment(\.dismiss) private var dismiss

    private let presets = [100_000, 250_000, 500_000, 1_000_000, 2_000_000, 5_000_000]

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily XP target") {
                    Text(target.grouped + " XP / day")
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                    Stepper(value: $target, in: 10_000...100_000_000, step: 50_000) {
                        Text("Adjust")
                    }
                }
                Section("Presets") {
                    ForEach(presets, id: \.self) { p in
                        Button {
                            target = p
                        } label: {
                            HStack {
                                Text(p.grouped)
                                Spacer()
                                if p == target {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
                Section {
                    Text("This target drives the in-app daily progress bar. Set the widget's own target by long-pressing the widget and choosing Edit.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Daily target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

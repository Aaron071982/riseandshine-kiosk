import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var state: KioskAppState
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
                .padding(.horizontal, 36)
                .padding(.top, 8)

            if state.usingCachedDirectory {
                cachedBanner
                    .padding(.horizontal, 36)
                    .padding(.top, 12)
            }

            if let error = state.searchError, state.searchResults.isEmpty {
                errorState(error)
            } else if state.searchResults.isEmpty && !state.isSearching {
                emptyState
            } else {
                results
            }
        }
        .onAppear { searchFocused = true }
    }

    private var header: some View {
        HStack(spacing: 16) {
            BackChip(title: "Home") { state.goIdle() }
            SunriseMark(size: 44) { state.requestStaffAudit() }
            VStack(alignment: .leading, spacing: 2) {
                Text("Who’s checking in?")
                    .font(RSFont.display(28, weight: .semibold))
                    .foregroundStyle(Color.espresso)
                Text(state.device?.locationLabel ?? "This location")
                    .font(RSFont.body(15))
                    .foregroundStyle(Color.mutedText)
            }
            Spacer()
            LiveClock(compact: true)
        }
        .padding(.horizontal, 36)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.mutedText)
            TextField("Search by first name…", text: Binding(
                get: { state.searchQuery },
                set: { state.searchChanged($0) }
            ))
            .font(RSFont.display(26, weight: .medium))
            .foregroundStyle(Color.espresso)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($searchFocused)
            if !state.searchQuery.isEmpty {
                Button {
                    state.searchChanged("")
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.mutedText)
                        .font(.system(size: 22))
                }
            }
        }
        .padding(.horizontal, 20)
        .frame(height: 72)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private var cachedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
            Text("Showing last directory — we’ll refresh when the network returns.")
                .font(RSFont.body(14, weight: .medium))
            Spacer()
        }
        .foregroundStyle(Color.sunriseDeep)
        .padding(12)
        .background(Color.sunriseTint)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(state.searchResults) { client in
                    Button { state.openDetail(client) } label: {
                        SearchRow(client: client)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 18)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Text(state.searchQuery.isEmpty ? "Start typing a name." : "No center clients match that search.")
                .font(RSFont.display(26, weight: .semibold))
                .foregroundStyle(Color.espresso)
            Text("Only children marked as center clients appear here.")
                .font(RSFont.body(16))
                .foregroundStyle(Color.mutedText)
            Spacer()
        }
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Spacer()
            Text("Can’t reach the directory")
                .font(RSFont.display(26, weight: .semibold))
                .foregroundStyle(Color.espresso)
            Text(message)
                .font(RSFont.body(16))
                .foregroundStyle(Color.mutedText)
                .multilineTextAlignment(.center)
            KioskButton(title: "Try again", kind: .secondary) {
                Task { await state.refreshDirectory(query: state.searchQuery) }
            }
            .frame(maxWidth: 280)
            Spacer()
        }
        .padding(40)
    }
}

struct SearchRow: View {
    let client: DirectoryClient

    var body: some View {
        HStack(spacing: 16) {
            InitialsAvatar(initials: client.initials, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(client.displayName)
                    .font(RSFont.display(22, weight: .semibold))
                    .foregroundStyle(Color.espresso)
                HStack(spacing: 8) {
                    if let session = client.todaySession {
                        Text(session.timeRange)
                        if let bt = session.btName, !bt.isEmpty {
                            Text("·")
                            Text(bt)
                        }
                    } else {
                        Text("No session on file today")
                    }
                }
                .font(RSFont.body(15))
                .foregroundStyle(Color.mutedText)
                .lineLimit(1)
            }
            Spacer()
            if !client.intakeComplete {
                Text("First visit")
                    .font(RSFont.body(13, weight: .semibold))
                    .foregroundStyle(Color.sunriseDeep)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.sunriseTint)
                    .clipShape(Capsule())
            }
            FormsPill(count: client.outstandingForms)
            StatusPill(signedIn: client.isSignedIn)
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.hairline)
        }
        .padding(.horizontal, 18)
        .frame(minHeight: 84)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }
}

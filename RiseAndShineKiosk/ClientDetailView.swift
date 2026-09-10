import SwiftUI

struct ClientDetailView: View {
    @EnvironmentObject private var state: KioskAppState
    @State private var showForms = false

    var body: some View {
        Group {
            if let client = state.selectedClient {
                content(client)
            } else {
                Color.clear.onAppear { state.openSearch() }
            }
        }
        .sheet(isPresented: $showForms) {
            if let client = state.selectedClient {
                FormsSheet(client: client)
            }
        }
    }

    private func content(_ client: DirectoryClient) -> some View {
        VStack(spacing: 0) {
            HStack {
                BackChip(title: "Search") { state.backFromDetail() }
                Spacer()
                LiveClock(compact: true)
            }
            .padding(.horizontal, 36)
            .padding(.top, 22)

            HStack(alignment: .top, spacing: 28) {
                leftColumn(client)
                rightColumn(client)
            }
            .padding(36)
        }
    }

    private func leftColumn(_ client: DirectoryClient) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center, spacing: 18) {
                InitialsAvatar(initials: client.initials, size: 92)
                VStack(alignment: .leading, spacing: 8) {
                    Text(client.displayName)
                        .font(RSFont.display(40, weight: .bold))
                        .foregroundStyle(Color.espresso)
                    StatusPill(signedIn: client.isSignedIn)
                }
                Spacer()
            }

            if client.outstandingForms > 0 {
                Button { showForms = true } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.sunriseDeep)
                            .frame(width: 44, height: 44)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(client.outstandingForms == 1 ? "1 form still open" : "\(client.outstandingForms) forms still open")
                                .font(RSFont.display(20, weight: .semibold))
                                .foregroundStyle(Color.espresso)
                            Text("Review on this iPad, then see the front desk for documents.")
                                .font(RSFont.body(14))
                                .foregroundStyle(Color.mutedText)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(Color.sunriseDeep)
                    }
                    .padding(18)
                    .background(Color.sunriseTint)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            if let parent = client.parentName, !parent.isEmpty {
                HStack(spacing: 8) {
                    Text("Signer on file")
                        .font(RSFont.body(14, weight: .medium))
                        .foregroundStyle(Color.mutedText)
                    Text(parent)
                        .font(RSFont.body(16, weight: .semibold))
                        .foregroundStyle(Color.espresso)
                    if let rel = client.parentRelationship, !rel.isEmpty {
                        Text("· \(rel)")
                            .font(RSFont.body(15))
                            .foregroundStyle(Color.mutedText)
                    }
                }
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func rightColumn(_ client: DirectoryClient) -> some View {
        VStack(spacing: 16) {
            KioskCard {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today’s session")
                        .font(RSFont.body(13, weight: .semibold))
                        .tracking(1.2)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.mutedText)

                    if let session = client.todaySession {
                        Text(session.timeRange)
                            .font(RSFont.display(36, weight: .semibold))
                            .foregroundStyle(Color.espresso)
                        sessionRow(icon: "person.fill", title: "Behavior technician", value: session.btName ?? "—")
                        sessionRow(icon: "mappin.and.ellipse", title: "Location", value: session.location ?? state.device?.locationLabel ?? "—")
                    } else {
                        Text("No session listed for today.")
                            .font(RSFont.display(24, weight: .semibold))
                            .foregroundStyle(Color.espresso)
                        Text("You can still sign in or out at this desk.")
                            .font(RSFont.body(16))
                            .foregroundStyle(Color.mutedText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            KioskButton(
                title: client.nextAction.verbTitle,
                icon: client.nextAction == .in ? "arrow.down.left.and.arrow.up.right" : "arrow.up.right.and.arrow.down.left",
                kind: client.nextAction == .out ? .primary : .primary
            ) {
                state.openSign()
            }
            Spacer()
        }
        .frame(maxWidth: 460)
    }

    private func sessionRow(icon: String, title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.sunrise)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(RSFont.body(13))
                    .foregroundStyle(Color.mutedText)
                Text(value)
                    .font(RSFont.body(18, weight: .semibold))
                    .foregroundStyle(Color.espresso)
            }
            Spacer()
        }
    }
}

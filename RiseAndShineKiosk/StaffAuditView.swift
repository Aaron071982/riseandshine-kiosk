import SwiftUI

struct StaffAuditView: View {
    @EnvironmentObject private var state: KioskAppState
    @State private var events: [AttendanceEvent] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                BackChip(title: "Home") { state.goIdle() }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today at this desk")
                        .font(RSFont.display(28, weight: .semibold))
                        .foregroundStyle(Color.espresso)
                    Text(state.device?.locationLabel ?? "This location")
                        .font(RSFont.body(15))
                        .foregroundStyle(Color.mutedText)
                }
                Spacer()
                if state.pendingCount > 0 {
                    Text("\(state.pendingCount) queued")
                        .font(RSFont.body(14, weight: .semibold))
                        .foregroundStyle(Color.sunriseDeep)
                        .padding(.horizontal, 12)
                        .frame(height: 36)
                        .background(Color.sunriseTint)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 36)
            .padding(.top, 22)
            .padding(.bottom, 12)

            if loading {
                Spacer()
                ProgressView().tint(Color.sunrise)
                Spacer()
            } else if let error {
                Spacer()
                Text(error)
                    .font(RSFont.body(17))
                    .foregroundStyle(Color.mutedText)
                KioskButton(title: "Retry", kind: .secondary) { Task { await load() } }
                    .frame(maxWidth: 240)
                    .padding(.top, 12)
                Spacer()
            } else if events.isEmpty {
                Spacer()
                Text("No check-ins yet today.")
                    .font(RSFont.display(26, weight: .semibold))
                    .foregroundStyle(Color.espresso)
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(events) { event in
                            auditRow(event)
                        }
                    }
                    .padding(.horizontal, 36)
                    .padding(.vertical, 12)
                }
            }
        }
        .task { await load() }
    }

    private func auditRow(_ event: AttendanceEvent) -> some View {
        HStack(spacing: 16) {
            Image(systemName: event.type == .out ? "arrow.up.right" : "arrow.down.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(event.type == .in ? Color.successGreen : Color.sunrise)
                .frame(width: 44, height: 44)
                .background(event.type == .in ? Color.successGreen.opacity(0.12) : Color.sunriseTint)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(event.clientDisplayName)
                    .font(RSFont.display(20, weight: .semibold))
                    .foregroundStyle(Color.espresso)
                Text("\(event.type?.statusLabel ?? "Event")  ·  \(event.signerName ?? "Signer")")
                    .font(RSFont.body(14))
                    .foregroundStyle(Color.mutedText)
            }
            Spacer()
            if let when = event.capturedAt ?? event.createdAt {
                Text(TimeFormatting.timeOnly.string(from: when))
                    .font(RSFont.display(18, weight: .semibold))
                    .foregroundStyle(Color.espresso)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 76)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private func load() async {
        loading = true
        error = nil
        do {
            events = try await state.api.todaysEvents()
        } catch {
            self.error = error.localizedDescription
        }
        loading = false
    }
}

struct StaffPINSheet: View {
    @EnvironmentObject private var state: KioskAppState
    @Environment(\.dismiss) private var dismiss
    @State private var digits = ""
    @State private var shake = false

    var body: some View {
        VStack(spacing: 18) {
            Text("Staff PIN")
                .font(RSFont.display(28, weight: .semibold))
                .foregroundStyle(Color.espresso)
            Text("Today’s check-ins at this location")
                .font(RSFont.body(15))
                .foregroundStyle(Color.mutedText)

            HStack(spacing: 12) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < digits.count ? Color.espresso : Color.hairline)
                        .frame(width: 16, height: 16)
                }
            }
            .offset(x: shake ? 10 : 0)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(["1","2","3","4","5","6","7","8","9","", "0", "⌫"], id: \.self) { key in
                    Button {
                        tap(key)
                    } label: {
                        Text(key)
                            .font(RSFont.display(26, weight: .semibold))
                            .foregroundStyle(Color.espresso)
                            .frame(maxWidth: .infinity)
                            .frame(height: 64)
                            .background(key.isEmpty ? Color.clear : Color.canvasBg)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(key.isEmpty)
                }
            }
        }
        .padding(28)
        .background(Color.white)
    }

    private func tap(_ key: String) {
        state.registerActivity()
        if key == "⌫" {
            if !digits.isEmpty { digits.removeLast() }
            return
        }
        guard digits.count < 4 else { return }
        digits.append(key)
        if digits.count == 4 {
            if digits == KioskConfig.staffPIN {
                dismiss()
                state.unlockStaffAudit()
            } else {
                withAnimation(.default) { shake = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    shake = false
                    digits = ""
                }
            }
        }
    }
}

import SwiftUI

struct ConfirmView: View {
    @EnvironmentObject private var state: KioskAppState

    var body: some View {
        if let payload = state.confirmPayload {
            VStack(spacing: 22) {
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.successGreen.opacity(0.14))
                        .frame(width: 140, height: 140)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 88))
                        .foregroundStyle(Color.successGreen)
                }
                Text("\(payload.client.firstName) is \(payload.direction.pastPhrase).")
                    .font(RSFont.display(48, weight: .bold))
                    .foregroundStyle(Color.espresso)
                    .multilineTextAlignment(.center)
                Text(payload.queuedOffline ? "Saved on this iPad — we’ll send it when we’re back online." : "Audit \(payload.eventId)")
                    .font(RSFont.body(18))
                    .foregroundStyle(Color.mutedText)
                    .multilineTextAlignment(.center)
                Spacer()
                Button("Done") { state.goIdle() }
                    .font(RSFont.body(18, weight: .semibold))
                    .foregroundStyle(Color.sunriseDeep)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 48)
        } else {
            Color.clear.onAppear { state.goIdle() }
        }
    }
}

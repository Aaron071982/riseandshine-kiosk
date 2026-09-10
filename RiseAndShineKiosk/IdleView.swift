import SwiftUI

struct IdleView: View {
    @EnvironmentObject private var state: KioskAppState

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                locationChip
                Spacer()
                LiveClock()
            }
            .padding(.horizontal, 40)
            .padding(.top, 28)

            Spacer()

            VStack(spacing: 22) {
                ZStack {
                    Circle()
                        .fill(Color.espresso)
                        .frame(width: 188, height: 188)
                        .shadow(color: Color.sunrise.opacity(0.28), radius: 28, y: 10)
                    SunriseMark(size: 128) {
                        state.requestStaffAudit()
                    }
                }

                Text("Rise & Shine")
                    .font(RSFont.body(15, weight: .semibold))
                    .tracking(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.sunriseDeep)

                Text("Welcome in.")
                    .font(RSFont.display(64, weight: .bold))
                    .foregroundStyle(Color.espresso)

                Text("Find a child to sign in or out.")
                    .font(RSFont.body(20))
                    .foregroundStyle(Color.mutedText)
            }

            Spacer()

            KioskButton(title: "Find a child", icon: "magnifyingglass") {
                state.openSearch()
            }
            .frame(maxWidth: 420)
            .padding(.bottom, 48)
        }
        .padding(.horizontal, 48)
    }

    private var locationChip: some View {
        HStack(spacing: 8) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 14, weight: .semibold))
            Text(state.device?.locationLabel ?? state.device?.label ?? "Front desk")
                .font(RSFont.body(15, weight: .medium))
        }
        .foregroundStyle(Color.mutedText)
        .padding(.horizontal, 14)
        .frame(height: 40)
        .background(Color.white.opacity(0.7))
        .clipShape(Capsule())
    }
}

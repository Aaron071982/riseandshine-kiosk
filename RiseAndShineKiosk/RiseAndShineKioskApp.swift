import SwiftUI

@main
struct RiseAndShineKioskApp: App {
    @StateObject private var state = KioskAppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .statusBarHidden(false)
                .preferredColorScheme(.light)
                .onAppear { state.bootstrap() }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var state: KioskAppState
    @ObservedObject private var network = NetworkMonitor.shared

    var body: some View {
        ZStack {
            KioskBackground()
            switch state.auth {
            case .launching:
                LaunchingView()
            case .needsSetup:
                DeviceSetupView()
            case .unauthorized:
                UnauthorizedView()
            case .ready:
                readyStack
            }
        }
        .animation(.easeInOut(duration: 0.25), value: state.auth)
        .animation(.easeInOut(duration: 0.22), value: state.screen)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0).onChanged { _ in state.registerActivity() }
        )
        .onChange(of: network.isOnline) { _, online in
            state.handleOnlineChange(online)
        }
        .sheet(isPresented: $state.showStaffPIN) {
            StaffPINSheet()
                .environmentObject(state)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $state.showSetup) {
            DeviceSetupView()
                .environmentObject(state)
        }
    }

    @ViewBuilder
    private var readyStack: some View {
        switch state.screen {
        case .idle: IdleView()
        case .search: SearchView()
        case .detail: ClientDetailView()
        case .sign: SignView()
        case .confirm: ConfirmView()
        case .staffAudit: StaffAuditView()
        }
    }
}

struct LaunchingView: View {
    var body: some View {
        VStack(spacing: 18) {
            SunriseMark(size: 120)
            ProgressView()
                .tint(Color.sunrise)
            Text("Checking this device…")
                .font(RSFont.body(16))
                .foregroundStyle(Color.mutedText)
        }
    }
}

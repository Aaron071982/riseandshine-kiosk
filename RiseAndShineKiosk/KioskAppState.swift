import Foundation
import SwiftUI
import CryptoKit
import UIKit

enum AuthState: Equatable {
    case launching
    case needsSetup
    case unauthorized
    case ready
}

enum KioskScreen: Equatable {
    case idle
    case search
    case detail
    case sign
    case confirm
    case staffAudit
}

@MainActor
final class KioskAppState: ObservableObject {
    @Published var auth: AuthState = .launching
    @Published var screen: KioskScreen = .idle
    @Published var device: DeviceInfo?
    @Published var selectedClient: DirectoryClient?
    @Published var confirmPayload: ConfirmPayload?
    @Published var searchQuery = ""
    @Published var searchResults: [DirectoryClient] = []
    @Published var isSearching = false
    @Published var usingCachedDirectory = false
    @Published var searchError: String?
    @Published var showStaffPIN = false
    @Published var showSetup = false
    @Published var isSubmitting = false
    @Published var pendingCount = 0

    private var lastActivity = Date()
    private var searchTask: Task<Void, Never>?
    private var inactivityTimer: Timer?
    private var confirmTask: Task<Void, Never>?
    private var wasOnline = true

    let api = KioskAPIClient.shared
    let network = NetworkMonitor.shared

    func bootstrap() {
        FontRegistration.registerBundledFonts()
        UIApplication.shared.isIdleTimerDisabled = true
        pendingCount = OfflineEventQueue.pendingCount()
        startInactivityWatch()
        Task { await validate() }
        Task { await observeNetwork() }
    }

    func registerActivity() {
        lastActivity = Date()
    }

    func goIdle() {
        confirmTask?.cancel()
        searchTask?.cancel()
        searchQuery = ""
        searchResults = []
        selectedClient = nil
        confirmPayload = nil
        showStaffPIN = false
        screen = .idle
        registerActivity()
    }

    func openSearch() {
        screen = .search
        registerActivity()
        Task { await refreshDirectory(query: searchQuery) }
    }

    func openDetail(_ client: DirectoryClient) {
        selectedClient = client
        screen = .detail
        registerActivity()
    }

    func openSign() {
        guard selectedClient != nil else { return }
        screen = .sign
        registerActivity()
    }

    func backFromDetail() {
        screen = .search
        selectedClient = nil
        registerActivity()
    }

    func backFromSign() {
        screen = .detail
        registerActivity()
    }

    func requestStaffAudit() {
        showStaffPIN = true
        registerActivity()
    }

    func unlockStaffAudit() {
        showStaffPIN = false
        screen = .staffAudit
        registerActivity()
    }

    func searchChanged(_ query: String) {
        searchQuery = query
        registerActivity()
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await refreshDirectory(query: query)
        }
    }

    func refreshDirectory(query: String) async {
        isSearching = true
        searchError = nil
        do {
            let results = try await api.directory(query: query)
            searchResults = results
            usingCachedDirectory = false
            if query.trimmingCharacters(in: .whitespaces).isEmpty {
                DirectoryCache.save(results)
            }
        } catch let error as KioskAPIError where error.isUnauthorized {
            auth = .unauthorized
        } catch {
            let cached = DirectoryCache.search(query)
            if cached.isEmpty {
                searchError = error.localizedDescription
                searchResults = []
                usingCachedDirectory = false
            } else {
                searchResults = cached
                usingCachedDirectory = true
                searchError = nil
            }
        }
        isSearching = false
    }

    func applyLocalStatusChange(clientId: String, direction: CheckDirection) {
        if var client = selectedClient, client.id == clientId {
            client.currentStatus = direction
            selectedClient = client
        }
        searchResults = searchResults.map { row in
            var copy = row
            if copy.id == clientId { copy.currentStatus = direction }
            return copy
        }
        var cached = DirectoryCache.load()
        cached = cached.map { row in
            var copy = row
            if copy.id == clientId { copy.currentStatus = direction }
            return copy
        }
        DirectoryCache.save(cached)
    }

    func submitCheckIn(
        png: Data,
        signerName: String,
        relationship: String
    ) async {
        guard let client = selectedClient else { return }
        isSubmitting = true
        let direction = client.nextAction
        let capturedAt = Date()
        let hash = SHA256.hash(data: png).map { String(format: "%02x", $0) }.joined()
        let request = CreateAttendanceEventRequest(
            clientId: client.id,
            type: direction.rawValue,
            signerName: signerName,
            signerRelationship: relationship,
            signaturePngBase64: png.base64EncodedString(),
            signatureHash: hash,
            capturedAt: ISO8601Parsing.string(from: capturedAt),
            scheduleAssignmentId: client.todaySession?.scheduleAssignmentId
        )

        do {
            let event = try await api.createEvent(request)
            finishSuccess(client: client, direction: direction, eventId: event.id, queued: false)
        } catch let error as KioskAPIError where error.isUnauthorized {
            auth = .unauthorized
        } catch {
            OfflineEventQueue.enqueue(
                request: request,
                png: png,
                client: client,
                direction: direction,
                capturedAt: capturedAt
            )
            pendingCount = OfflineEventQueue.pendingCount()
            finishSuccess(client: client, direction: direction, eventId: "offline-\(UUID().uuidString.prefix(8))", queued: true)
        }
        isSubmitting = false
    }

    private func finishSuccess(client: DirectoryClient, direction: CheckDirection, eventId: String, queued: Bool) {
        applyLocalStatusChange(clientId: client.id, direction: direction)
        confirmPayload = ConfirmPayload(client: client, direction: direction, eventId: eventId, queuedOffline: queued)
        screen = .confirm
        registerActivity()
        confirmTask?.cancel()
        confirmTask = Task {
            try? await Task.sleep(nanoseconds: 7_000_000_000)
            guard !Task.isCancelled else { return }
            goIdle()
        }
    }

    func validate() async {
        guard KioskConfig.isConfigured else {
            auth = .needsSetup
            return
        }
        do {
            device = try await api.validateSession()
            auth = .ready
            screen = .idle
            await OfflineEventQueue.flush()
            pendingCount = OfflineEventQueue.pendingCount()
        } catch let error as KioskAPIError where error.isUnauthorized {
            auth = .unauthorized
        } catch {
            // Offline / HRM unreachable: still allow kiosk if a token exists.
            auth = .ready
            screen = .idle
        }
    }

    func saveProvisioning(baseURL: String, token: String, staffPIN: String) async {
        KioskConfig.baseURLString = baseURL
        KioskConfig.staffPIN = staffPIN
        try? KeychainStore.saveToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
        showSetup = false
        auth = .launching
        await validate()
    }

    func clearProvisioning() {
        KeychainStore.deleteToken()
        auth = .needsSetup
        device = nil
    }

    private func startInactivityWatch() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tickInactivity()
            }
        }
    }

    private func tickInactivity() {
        guard auth == .ready else { return }
        guard screen != .idle, screen != .confirm else { return }
        if Date().timeIntervalSince(lastActivity) >= 60 {
            goIdle()
        }
    }

    private func observeNetwork() async {
        wasOnline = network.isOnline
    }

    func handleOnlineChange(_ online: Bool) {
        if online && !wasOnline {
            Task {
                await OfflineEventQueue.flush()
                pendingCount = OfflineEventQueue.pendingCount()
            }
        }
        wasOnline = online
    }
}

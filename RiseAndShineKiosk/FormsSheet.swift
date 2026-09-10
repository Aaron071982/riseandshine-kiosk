import SwiftUI

struct FormsSheet: View {
    let client: DirectoryClient
    @Environment(\.dismiss) private var dismiss
    @State private var infoCurrent = false
    @State private var pickupAuthorized = false
    @State private var noticesOffered = false

    private var allChecked: Bool { infoCurrent && pickupAuthorized && noticesOffered }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("\(client.firstName) has \(client.outstandingForms) open \(client.outstandingForms == 1 ? "form" : "forms").")
                        .font(RSFont.display(32, weight: .semibold))
                        .foregroundStyle(Color.espresso)

                    Text("Simple acknowledgements can be made here. Anything that needs a document or signature packet is completed at the front desk — this kiosk doesn’t fill those out.")
                        .font(RSFont.body(17))
                        .foregroundStyle(Color.mutedText)

                    VStack(spacing: 12) {
                        attest("Contact and pickup information on file is still current.", $infoCurrent)
                        attest("I am authorized to sign \(client.firstName) in or out today.", $pickupAuthorized)
                        attest("I’ve been offered copies of any notices waiting at the desk.", $noticesOffered)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "building.columns.fill")
                            .foregroundStyle(Color.sunriseDeep)
                            .font(.system(size: 20))
                        Text("Remaining document types — consents, assessments, and packets — please see the front desk.")
                            .font(RSFont.body(16, weight: .medium))
                            .foregroundStyle(Color.espresso)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.sunriseTint)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(28)
            }
            .background(Color.canvasBg)
            .safeAreaInset(edge: .bottom) {
                KioskButton(title: allChecked ? "Acknowledged" : "Check each item", enabled: allChecked) {
                    dismiss()
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
                .background(Color.canvasBg)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .font(RSFont.body(16, weight: .semibold))
                }
            }
        }
    }

    private func attest(_ text: String, _ bound: Binding<Bool>) -> some View {
        Button {
            bound.wrappedValue.toggle()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: bound.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(bound.wrappedValue ? Color.sunrise : Color.hairline)
                Text(text)
                    .font(RSFont.body(17, weight: .medium))
                    .foregroundStyle(Color.espresso)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(bound.wrappedValue ? Color.sunrise.opacity(0.4) : Color.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 72)
    }
}

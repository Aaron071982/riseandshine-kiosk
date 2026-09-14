import SwiftUI
import PencilKit

struct SignView: View {
    @EnvironmentObject private var state: KioskAppState
    @State private var drawing = PKDrawing()
    @State private var isEmpty = true
    @State private var someoneElse = false
    @State private var signerName = ""
    @State private var relationship = "Parent"
    @State private var canvasSize = CGSize(width: 640, height: 280)

    private let relationships = ["Parent", "Guardian", "Mother", "Father", "Caregiver", "Staff", "Someone else"]

    var body: some View {
        Group {
            if let client = state.selectedClient {
                content(client)
            } else {
                Color.clear.onAppear { state.openSearch() }
            }
        }
        .onAppear { prefill() }
    }

    private func prefill() {
        guard let client = state.selectedClient else { return }
        if let name = client.parentName, !name.isEmpty {
            signerName = name
            relationship = client.parentRelationship?.isEmpty == false ? client.parentRelationship! : "Parent"
            someoneElse = false
        } else {
            someoneElse = true
            signerName = ""
            relationship = "Parent"
        }
    }

    private func content(_ client: DirectoryClient) -> some View {
        VStack(spacing: 0) {
            HStack {
                BackChip(title: "Back") { state.backFromSign() }
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(client.nextAction.verbTitle)  ·  \(client.firstName)")
                        .font(RSFont.display(26, weight: .semibold))
                        .foregroundStyle(Color.espresso)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(TimeFormatting.stamp.string(from: context.date))
                            .font(RSFont.body(15))
                            .foregroundStyle(Color.mutedText)
                    }
                }
                Spacer()
                Button("Clear pad") {
                    drawing = PKDrawing()
                    isEmpty = true
                    state.registerActivity()
                }
                .font(RSFont.body(16, weight: .semibold))
                .foregroundStyle(Color.sunriseDeep)
            }
            .padding(.horizontal, 32)
            .padding(.top, 18)
            .padding(.bottom, 8)

            HStack(alignment: .top, spacing: 24) {
                signerColumn(client)
                padColumn
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private func signerColumn(_ client: DirectoryClient) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Who’s signing?")
                .font(RSFont.body(13, weight: .semibold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Color.mutedText)

            if let parent = client.parentName, !parent.isEmpty {
                signerChip(
                    title: parent,
                    subtitle: client.parentRelationship ?? "Parent",
                    selected: !someoneElse
                ) {
                    someoneElse = false
                    signerName = parent
                    relationship = client.parentRelationship?.isEmpty == false ? client.parentRelationship! : "Parent"
                    state.registerActivity()
                }
            }

            signerChip(title: "Someone else", subtitle: "Enter name and relationship", selected: someoneElse) {
                someoneElse = true
                state.registerActivity()
            }

            if someoneElse {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Full name", text: $signerName)
                        .font(RSFont.body(18, weight: .medium))
                        .padding(.horizontal, 14)
                        .frame(height: 56)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.hairline, lineWidth: 1)
                        )
                        .onChange(of: signerName) { _, _ in state.registerActivity() }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(relationships, id: \.self) { rel in
                                Button {
                                    relationship = rel
                                    state.registerActivity()
                                } label: {
                                    Text(rel)
                                        .font(RSFont.body(14, weight: .semibold))
                                        .foregroundStyle(relationship == rel ? Color.white : Color.espresso)
                                        .padding(.horizontal, 12)
                                        .frame(height: 40)
                                        .background(relationship == rel ? Color.espresso : Color.white)
                                        .clipShape(Capsule())
                                        .overlay(Capsule().stroke(Color.hairline, lineWidth: relationship == rel ? 0 : 1))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }

            Spacer()

            if let submitError = state.submitError {
                Text(submitError)
                    .font(RSFont.body(15, weight: .medium))
                    .foregroundStyle(Color.sunriseDeep)
                    .multilineTextAlignment(.leading)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.sunriseTint)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            TimelineView(.periodic(from: .now, by: 1)) { context in
                KioskButton(
                    title: "Confirm \(client.nextAction.verbTitle.lowercased())  ·  \(TimeFormatting.timeOnly.string(from: context.date))",
                    kind: .success,
                    enabled: canSubmit,
                    loading: state.isSubmitting
                ) {
                    submit()
                }
            }
        }
        .frame(width: 340)
    }

    private var padColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Signature")
                .font(RSFont.body(13, weight: .semibold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Color.mutedText)
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white)
                if isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "signature")
                            .font(.system(size: 36))
                            .foregroundStyle(Color.hairline)
                        Text("Sign with a finger or Apple Pencil")
                            .font(RSFont.body(16))
                            .foregroundStyle(Color.mutedText)
                    }
                    .allowsHitTesting(false)
                }
                SignatureCanvas(drawing: $drawing, isEmpty: $isEmpty, onActivity: { state.registerActivity() })
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear { canvasSize = geo.size }
                                .onChange(of: geo.size) { _, size in canvasSize = size }
                        }
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var canSubmit: Bool {
        !isEmpty && !signerName.trimmingCharacters(in: .whitespaces).isEmpty && !state.isSubmitting
    }

    private func signerChip(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .strokeBorder(selected ? Color.sunrise : Color.hairline, lineWidth: 2)
                    .background(Circle().fill(selected ? Color.sunrise : Color.clear))
                    .frame(width: 18, height: 18)
                    .overlay {
                        if selected {
                            Circle().fill(Color.white).frame(width: 6, height: 6)
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(RSFont.body(17, weight: .semibold))
                        .foregroundStyle(Color.espresso)
                    Text(subtitle)
                        .font(RSFont.body(13))
                        .foregroundStyle(Color.mutedText)
                }
                Spacer()
            }
            .padding(14)
            .background(selected ? Color.sunriseTint : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Color.sunrise.opacity(0.5) : Color.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 64)
    }

    private func submit() {
        let signatureImage = SignatureExport.image(from: drawing, size: canvasSize)
        Task {
            await state.submitCheckIn(
                signatureImage: signatureImage,
                signerName: signerName.trimmingCharacters(in: .whitespaces),
                relationship: relationship
            )
        }
    }
}

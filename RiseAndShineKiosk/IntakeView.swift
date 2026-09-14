import SwiftUI
import PencilKit

struct IntakeView: View {
    @EnvironmentObject private var state: KioskAppState
    @ObservedObject var intake: IntakeController
    @State private var canvasSize = CGSize(width: 640, height: 220)

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch intake.currentStep {
                case .welcome:
                    welcome
                case .gate(let code):
                    if let form = intake.form(code: code) {
                        gate(form)
                    }
                case .section(let code, let idx):
                    if let form = intake.form(code: code), form.sections.indices.contains(idx) {
                        section(form: form, index: idx)
                    }
                case .review:
                    review
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            BackChip(title: intake.stepIndex == 0 ? "Search" : "Back") {
                if intake.stepIndex == 0 {
                    state.cancelIntake()
                } else {
                    intake.goBack()
                    state.registerActivity()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("First-visit forms")
                    .font(RSFont.display(24, weight: .semibold))
                    .foregroundStyle(Color.espresso)
                Text(intake.progressLabel)
                    .font(RSFont.body(15))
                    .foregroundStyle(Color.mutedText)
            }
            Spacer()
            progressDots
        }
        .padding(.horizontal, 32)
        .padding(.top, 18)
        .padding(.bottom, 8)
    }

    private var progressDots: some View {
        let total = max(intake.steps.count, 1)
        let idx = intake.stepIndex
        return Text("\(min(idx + 1, total)) / \(total)")
            .font(RSFont.body(14, weight: .semibold))
            .foregroundStyle(Color.mutedText)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.hairline, lineWidth: 1))
    }

    private var welcome: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                InitialsAvatar(initials: intake.client.initials, size: 88)
                Text("First visit for \(intake.client.firstName)!")
                    .font(RSFont.display(42, weight: .bold))
                    .foregroundStyle(Color.espresso)
                    .multilineTextAlignment(.center)
                Text("A few quick forms before today’s session.")
                    .font(RSFont.body(20))
                    .foregroundStyle(Color.mutedText)
                HStack(spacing: 28) {
                    infoChip("Child", intake.client.displayName)
                    infoChip("Date of birth", DateDisplay.mmddyyyy(from: intake.client.dateOfBirth) ?? "On file")
                }
                .padding(.top, 8)
            }
            Spacer()
            KioskButton(title: "Let’s go") {
                state.registerActivity()
                intake.advance()
            }
            .frame(maxWidth: 360)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 48)
    }

    private func infoChip(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(RSFont.body(13, weight: .semibold))
                .foregroundStyle(Color.mutedText)
            Text(value)
                .font(RSFont.display(20, weight: .semibold))
                .foregroundStyle(Color.espresso)
        }
        .padding(16)
        .frame(minWidth: 220, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.hairline, lineWidth: 1)
        )
    }

    private func gate(_ form: IntakeForm) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 16) {
                Text(form.conditionalGate?.prompt ?? "")
                    .font(RSFont.display(36, weight: .semibold))
                    .foregroundStyle(Color.espresso)
                    .multilineTextAlignment(.center)
                Text("If not, we’ll skip this form.")
                    .font(RSFont.body(18))
                    .foregroundStyle(Color.mutedText)
            }
            .padding(.horizontal, 48)
            Spacer()
            HStack(spacing: 16) {
                KioskButton(title: "No", kind: .secondary) {
                    state.registerActivity()
                    intake.answerGate(formCode: form.code, yes: false)
                }
                KioskButton(title: "Yes") {
                    state.registerActivity()
                    intake.answerGate(formCode: form.code, yes: true)
                }
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 32)
        }
    }

    private func section(form: IntakeForm, index: Int) -> some View {
        let section = form.sections[index]
        return VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(form.title)
                        .font(RSFont.body(14, weight: .semibold))
                        .tracking(1.1)
                        .textCase(.uppercase)
                        .foregroundStyle(Color.sunriseDeep)
                    Text(section.title)
                        .font(RSFont.display(32, weight: .semibold))
                        .foregroundStyle(Color.espresso)
                    if let body = section.body, !body.isEmpty {
                        Text(body)
                            .font(RSFont.body(17))
                            .foregroundStyle(Color.mutedText)
                    }
                    ForEach(section.fields) { field in
                        IntakeFieldControl(formCode: form.code, field: field, intake: intake)
                    }
                    if let message = intake.validationMessage {
                        Text(message)
                            .font(RSFont.body(15, weight: .medium))
                            .foregroundStyle(Color.sunriseDeep)
                    }
                }
                .padding(32)
            }
            HStack(spacing: 12) {
                if form.isOptional {
                    KioskButton(title: "Skip, not applicable", kind: .secondary) {
                        state.registerActivity()
                        intake.skipOptionalForm(form.code)
                    }
                }
                KioskButton(title: "Continue") {
                    state.registerActivity()
                    intake.advance()
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
    }

    private var review: some View {
        HStack(alignment: .top, spacing: 24) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Review")
                        .font(RSFont.display(28, weight: .semibold))
                        .foregroundStyle(Color.espresso)
                    ForEach(intake.summaryRows(), id: \.form) { row in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(row.title)
                                .font(RSFont.body(15, weight: .semibold))
                                .foregroundStyle(Color.sunriseDeep)
                            if row.items.isEmpty {
                                Text("Acknowledged")
                                    .font(RSFont.body(15))
                                    .foregroundStyle(Color.mutedText)
                            } else {
                                ForEach(Array(row.items.enumerated()), id: \.offset) { _, item in
                                    HStack(alignment: .top) {
                                        Text(item.0)
                                            .font(RSFont.body(14))
                                            .foregroundStyle(Color.mutedText)
                                        Spacer(minLength: 12)
                                        Text(item.1 == "Yes" ? "Yes" : item.1)
                                            .font(RSFont.body(14, weight: .semibold))
                                            .foregroundStyle(Color.espresso)
                                            .multilineTextAlignment(.trailing)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.hairline, lineWidth: 1)
                        )
                    }
                }
                .padding(.leading, 32)
                .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)

            VStack(alignment: .leading, spacing: 12) {
                Text("Sign the packet")
                    .font(RSFont.display(24, weight: .semibold))
                    .foregroundStyle(Color.espresso)
                Text(intake.schema.signature.consentText)
                    .font(RSFont.body(15))
                    .foregroundStyle(Color.mutedText)
                    .fixedSize(horizontal: false, vertical: true)

                signerChips

                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                    if intake.signatureEmpty {
                        Text("Sign with a finger or Apple Pencil")
                            .font(RSFont.body(15))
                            .foregroundStyle(Color.mutedText)
                            .allowsHitTesting(false)
                    }
                    SignatureCanvas(
                        drawing: $intake.drawing,
                        isEmpty: $intake.signatureEmpty,
                        onActivity: { state.registerActivity() }
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear { canvasSize = geo.size }
                                .onChange(of: geo.size) { _, size in canvasSize = size }
                        }
                    )
                }
                .frame(height: 180)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.hairline, lineWidth: 1)
                )

                Button("Clear signature") {
                    intake.drawing = PKDrawing()
                    intake.signatureEmpty = true
                    state.registerActivity()
                }
                .font(RSFont.body(15, weight: .semibold))
                .foregroundStyle(Color.sunriseDeep)

                if let error = intake.submitError {
                    Text(error)
                        .font(RSFont.body(15, weight: .medium))
                        .foregroundStyle(Color.sunriseDeep)
                }

                KioskButton(
                    title: "Submit packet",
                    kind: .success,
                    enabled: canSubmit,
                    loading: intake.isSubmitting
                ) {
                    submit()
                }
            }
            .frame(width: 420)
            .padding(.trailing, 32)
            .padding(.bottom, 24)
        }
    }

    private var signerChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let parent = intake.client.parentName, !parent.isEmpty {
                signerChip(title: parent, subtitle: intake.client.parentRelationship ?? "Parent", selected: !intake.someoneElse) {
                    intake.someoneElse = false
                    intake.signerName = parent
                    intake.relationship = intake.client.parentRelationship?.isEmpty == false ? intake.client.parentRelationship! : "Parent"
                    state.registerActivity()
                }
            }
            signerChip(title: "Someone else", subtitle: "Name and relationship", selected: intake.someoneElse) {
                intake.someoneElse = true
                state.registerActivity()
            }
            if intake.someoneElse {
                TextField("Full name", text: $intake.signerName)
                    .font(RSFont.body(17, weight: .medium))
                    .padding(.horizontal, 14)
                    .frame(height: 52)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.hairline, lineWidth: 1)
                    )
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(intake.relationships, id: \.self) { rel in
                            Button {
                                intake.relationship = rel
                                state.registerActivity()
                            } label: {
                                Text(rel)
                                    .font(RSFont.body(13, weight: .semibold))
                                    .foregroundStyle(intake.relationship == rel ? Color.white : Color.espresso)
                                    .padding(.horizontal, 12)
                                    .frame(height: 36)
                                    .background(intake.relationship == rel ? Color.espresso : Color.white)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func signerChip(title: String, subtitle: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(RSFont.body(16, weight: .semibold))
                        .foregroundStyle(Color.espresso)
                    Text(subtitle)
                        .font(RSFont.body(13))
                        .foregroundStyle(Color.mutedText)
                }
                Spacer()
            }
            .padding(12)
            .background(selected ? Color.sunriseTint : Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color.sunrise.opacity(0.5) : Color.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(minHeight: 56)
    }

    private var canSubmit: Bool {
        !intake.signatureEmpty
            && !intake.signerName.trimmingCharacters(in: .whitespaces).isEmpty
            && !intake.isSubmitting
    }

    private func submit() {
        let image = SignatureExport.image(from: intake.drawing, size: canvasSize)
        Task { await state.submitIntake(signatureImage: image) }
    }
}

struct IntakeFieldControl: View {
    let formCode: String
    let field: IntakeField
    @ObservedObject var intake: IntakeController
    @EnvironmentObject private var state: KioskAppState

    var body: some View {
        Group {
            switch field.type {
            case .checkbox:
                checkbox
            case .radio:
                radio
            case .textarea:
                textArea
            case .date:
                dateField
            case .text:
                textField
            }
        }
        .onChange(of: intake.answers[formCode]?[field.id]) { _, _ in
            state.registerActivity()
        }
    }

    private var checkbox: some View {
        Button {
            let next = !intake.boolValue(form: formCode, field: field.id)
            intake.set(.bool(next), form: formCode, field: field.id)
            state.registerActivity()
        } label: {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: intake.boolValue(form: formCode, field: field.id) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28))
                    .foregroundStyle(intake.boolValue(form: formCode, field: field.id) ? Color.sunrise : Color.hairline)
                Text(field.label)
                    .font(RSFont.body(17, weight: .medium))
                    .foregroundStyle(Color.espresso)
                    .multilineTextAlignment(.leading)
                Spacer()
            }
            .padding(16)
            .frame(minHeight: 64)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(intake.boolValue(form: formCode, field: field.id) ? Color.sunrise.opacity(0.45) : Color.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var radio: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label)
                .font(RSFont.body(15, weight: .semibold))
                .foregroundStyle(Color.mutedText)
            ForEach(field.options ?? []) { option in
                let selected = intake.stringValue(form: formCode, field: field.id) == option.value
                Button {
                    intake.set(.string(option.value), form: formCode, field: field.id)
                    state.registerActivity()
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                            .foregroundStyle(selected ? Color.sunrise : Color.hairline)
                            .font(.system(size: 24))
                        Text(option.label)
                            .font(RSFont.body(17, weight: .medium))
                            .foregroundStyle(Color.espresso)
                            .multilineTextAlignment(.leading)
                        Spacer()
                    }
                    .padding(16)
                    .frame(minHeight: 64)
                    .background(selected ? Color.sunriseTint : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var textField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label)
                .font(RSFont.body(14, weight: .semibold))
                .foregroundStyle(Color.mutedText)
            TextField(field.label, text: textBinding)
                .font(RSFont.body(18))
                .padding(.horizontal, 14)
                .frame(height: 56)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.hairline, lineWidth: 1)
                )
        }
    }

    private var textArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label)
                .font(RSFont.body(14, weight: .semibold))
                .foregroundStyle(Color.mutedText)
            TextField(field.label, text: textBinding, axis: .vertical)
                .font(RSFont.body(18))
                .lineLimit(3...6)
                .padding(14)
                .frame(minHeight: 96, alignment: .topLeading)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.hairline, lineWidth: 1)
                )
        }
    }

    private var dateField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(field.label)
                .font(RSFont.body(14, weight: .semibold))
                .foregroundStyle(Color.mutedText)
            DatePicker(
                field.label,
                selection: dateBinding,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .padding(.horizontal, 12)
            .frame(height: 56)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.hairline, lineWidth: 1)
            )
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { intake.stringValue(form: formCode, field: field.id) },
            set: { intake.set(.string($0), form: formCode, field: field.id) }
        )
    }

    private var dateBinding: Binding<Date> {
        Binding(
            get: {
                let raw = intake.stringValue(form: formCode, field: field.id)
                return DateDisplay.mmddyyyy.date(from: raw) ?? Date()
            },
            set: {
                intake.set(.string(DateDisplay.mmddyyyy.string(from: $0)), form: formCode, field: field.id)
            }
        )
    }
}

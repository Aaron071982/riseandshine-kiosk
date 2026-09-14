import Foundation
import PencilKit
import SwiftUI

enum IntakeStep: Equatable {
    case welcome
    case gate(String)
    case section(formCode: String, sectionIndex: Int)
    case review
}

@MainActor
final class IntakeController: ObservableObject {
    let client: DirectoryClient
    let schema: IntakeSchema

    @Published var stepIndex = 0
    @Published var answers: [String: [String: IntakeFieldValue]] = [:]
    @Published var skippedForms: Set<String> = []
    @Published var gateYes: Set<String> = []
    @Published var gateNo: Set<String> = []
    @Published var validationMessage: String?
    @Published var submitError: String?
    @Published var isSubmitting = false
    @Published var signerName = ""
    @Published var relationship = "Parent"
    @Published var someoneElse = false
    @Published var drawing = PKDrawing()
    @Published var signatureEmpty = true
    @Published var consentAccepted = false

    let relationships = ["Parent", "Guardian", "Mother", "Father", "Caregiver", "Staff", "Someone else"]

    init(client: DirectoryClient, schema: IntakeSchema = IntakeSchemaLoader.load()) {
        self.client = client
        self.schema = schema
        if let name = client.parentName, !name.isEmpty {
            signerName = name
            relationship = client.parentRelationship?.isEmpty == false ? client.parentRelationship! : "Parent"
            someoneElse = false
        } else {
            someoneElse = true
        }
    }

    var steps: [IntakeStep] {
        var list: [IntakeStep] = [.welcome]
        for form in schema.enabledForms {
            if skippedForms.contains(form.code) { continue }
            if let gate = form.conditionalGate {
                list.append(.gate(form.code))
                if gateNo.contains(form.code) { continue }
                if gate.showsOnYes, !gateYes.contains(form.code) { continue }
            }
            if skippedForms.contains(form.code) { continue }
            for (idx, _) in form.sections.enumerated() {
                list.append(.section(formCode: form.code, sectionIndex: idx))
            }
        }
        list.append(.review)
        return list
    }

    var currentStep: IntakeStep {
        let all = steps
        let idx = min(max(stepIndex, 0), all.count - 1)
        return all[idx]
    }

    var progressLabel: String {
        switch currentStep {
        case .welcome: return "Welcome"
        case .review: return "Review"
        case .gate(let code), .section(formCode: let code, _):
            let codes = visibleFormCodes
            if let i = codes.firstIndex(of: code) {
                return "Form \(i + 1) of \(codes.count)"
            }
            return "Forms"
        }
    }

    var visibleFormCodes: [String] {
        schema.enabledForms.compactMap { form in
            if skippedForms.contains(form.code) { return nil }
            if form.conditionalGate != nil, gateNo.contains(form.code) { return nil }
            if form.conditionalGate != nil, !gateYes.contains(form.code), !gateNo.contains(form.code) {
                return form.code
            }
            return form.code
        }
    }

    func form(code: String) -> IntakeForm? {
        schema.enabledForms.first { $0.code == code }
    }

    func boolValue(form: String, field: String) -> Bool {
        answers[form]?[field]?.isChecked ?? false
    }

    func stringValue(form: String, field: String) -> String {
        if case .string(let s) = answers[form]?[field] { return s }
        return ""
    }

    func set(_ value: IntakeFieldValue, form: String, field: String) {
        var bucket = answers[form] ?? [:]
        switch value {
        case .bool(let v):
            if v { bucket[field] = value } else { bucket.removeValue(forKey: field) }
        case .string(let s):
            if s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                bucket.removeValue(forKey: field)
            } else {
                bucket[field] = value
            }
        }
        if bucket.isEmpty { answers.removeValue(forKey: form) } else { answers[form] = bucket }
        validationMessage = nil
        submitError = nil
    }

    func answerGate(formCode: String, yes: Bool) {
        if yes {
            gateYes.insert(formCode)
            gateNo.remove(formCode)
            skippedForms.remove(formCode)
        } else {
            gateNo.insert(formCode)
            gateYes.remove(formCode)
            answers.removeValue(forKey: formCode)
        }
        validationMessage = nil
        advance()
    }

    func skipOptionalForm(_ code: String) {
        skippedForms.insert(code)
        answers.removeValue(forKey: code)
        validationMessage = nil
        let origin = schema.enabledForms.firstIndex(where: { $0.code == code }) ?? 0
        let later = Set(schema.enabledForms.dropFirst(origin + 1).map(\.code))
        let all = steps
        if let idx = all.firstIndex(where: { step in
            switch step {
            case .gate(let c), .section(formCode: let c, _): return later.contains(c)
            case .review: return true
            case .welcome: return false
            }
        }) {
            stepIndex = idx
        } else {
            stepIndex = max(all.count - 1, 0)
        }
    }

    func goBack() {
        validationMessage = nil
        submitError = nil
        stepIndex = max(0, stepIndex - 1)
    }

    func advance() {
        if !validateCurrent() { return }
        let all = steps
        if let current = all.firstIndex(of: currentStep) {
            stepIndex = min(current + 1, all.count - 1)
        } else {
            stepIndex = min(stepIndex + 1, all.count - 1)
        }
    }

    func validateCurrent() -> Bool {
        switch currentStep {
        case .welcome, .gate, .review:
            return true
        case .section(let code, let idx):
            guard let form = form(code: code), form.sections.indices.contains(idx) else { return true }
            let section = form.sections[idx]
            for field in section.fields where field.mustAnswer(formIsShown: true) {
                if !isAnswered(form: code, field: field) {
                    validationMessage = field.type == .checkbox
                        ? "Please check: \(field.label)"
                        : "Please fill in: \(field.label)"
                    return false
                }
            }
            return true
        }
    }

    func isAnswered(form: String, field: IntakeField) -> Bool {
        answers[form]?[field.id]?.isPresent ?? false
    }

    func payloadForms() -> [String: [String: IntakeJSONValue]] {
        var out: [String: [String: IntakeJSONValue]] = [:]
        let skipIds: Set<String> = ["child_name", "dob", "print_name", "sig_date"]
        for (code, fields) in answers {
            if skippedForms.contains(code) { continue }
            if gateNo.contains(code) { continue }
            var payload: [String: IntakeJSONValue] = [:]
            for (id, value) in fields {
                if skipIds.contains(id) { continue }
                switch value {
                case .bool(true): payload[id] = .bool(true)
                case .bool(false): break
                case .string(let s):
                    let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { payload[id] = .string(trimmed) }
                }
            }
            if !payload.isEmpty { out[code] = payload }
        }
        return out
    }

    func summaryRows() -> [(form: String, title: String, items: [(String, String)])] {
        schema.enabledForms.compactMap { form in
            if skippedForms.contains(form.code) || gateNo.contains(form.code) { return nil }
            let values = answers[form.code] ?? [:]
            var items: [(String, String)] = []
            for section in form.sections {
                for field in section.fields {
                    guard let value = values[field.id], value.isPresent else { continue }
                    items.append((field.label, value.stringValue))
                }
            }
            if items.isEmpty && form.isOptional { return nil }
            return (form.code, form.title, items)
        }
    }
}

import SwiftUI
import PencilKit
import UIKit

struct SignatureCanvas: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    var isEmpty: Binding<Bool>
    var onActivity: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.delegate = context.coordinator
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: UIColor(Color.espresso), width: 3.4)
        canvas.overrideUserInterfaceStyle = .light
        canvas.drawing = drawing
        return canvas
    }

    func updateUIView(_ canvas: PKCanvasView, context: Context) {
        context.coordinator.parent = self
        if canvas.drawing != drawing {
            canvas.drawing = drawing
        }
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: SignatureCanvas
        init(_ parent: SignatureCanvas) { self.parent = parent }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.isEmpty.wrappedValue = canvasView.drawing.strokes.isEmpty
            parent.onActivity()
        }
    }
}

enum SignatureExport {
    static func image(from drawing: PKDrawing, size: CGSize) -> UIImage {
        drawing.image(from: CGRect(origin: .zero, size: size), scale: 2)
    }
}

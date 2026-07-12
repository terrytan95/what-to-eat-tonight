import SwiftUI
import VisionKit

struct InventoryScanner: UIViewControllerRepresentable {
    static var isAvailable: Bool { DataScannerViewController.isSupported && DataScannerViewController.isAvailable }
    let onResult: (String, String?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onResult: onResult) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.text(languages: ["zh-Hans", "en"]), .barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onResult: (String, String?) -> Void
        init(onResult: @escaping (String, String?) -> Void) { self.onResult = onResult }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) { handle(item) }

        private func handle(_ item: RecognizedItem) {
            dataScannerResult(item).map { onResult($0.name, $0.barcode) }
        }

        private func dataScannerResult(_ item: RecognizedItem) -> (name: String, barcode: String?)? {
            switch item {
            case .text(let text):
                let value = text.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : (value, nil)
            case .barcode(let barcode):
                guard let value = barcode.payloadStringValue, !value.isEmpty else { return nil }
                return ("", value)
            @unknown default:
                return nil
            }
        }
    }
}

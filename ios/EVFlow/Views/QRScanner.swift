import SwiftUI
import VisionKit
import AVFoundation

/// Full-screen QR scan of the code printed on the charger; the first code read is handed to `onCode`.
struct QRScannerScreen: View {
    let onCode: (String) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    VisionQRScanner(onCode: onCode)
                } else {
                    AVQRScanner(onCode: onCode)
                }
            }
            .ignoresSafeArea()

            HStack {
                Button(action: onClose) {
                    Icon("x", size: 20, color: .white).frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.45)))
                }
                Spacer()
                Text("Nuskenuok jungties QR kodą").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 14).frame(height: 36).background(Capsule().fill(.black.opacity(0.45)))
                Spacer()
                Color.clear.frame(width: 44, height: 44)
            }
            .padding(.horizontal, W.margin).padding(.top, 8)
        }
        .background(Color.black.ignoresSafeArea())
    }
}

/// VisionKit live scanner, QR only.
private struct VisionQRScanner: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let vc = DataScannerViewController(recognizedDataTypes: [.barcode(symbologies: [.qr])], qualityLevel: .balanced,
                                           isHighlightingEnabled: true)
        vc.delegate = context.coordinator
        try? vc.startScanning()
        return vc
    }

    func updateUIViewController(_ vc: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        private var done = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func dataScanner(_ s: DataScannerViewController, didAdd items: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !done else { return }
            for case .barcode(let b) in items {
                if let text = b.payloadStringValue { done = true; s.stopScanning(); onCode(text); return }
            }
        }
    }
}

/// Fallback for devices without VisionKit scanning: AVFoundation metadata output, QR only.
private struct AVQRScanner: UIViewRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        let session = context.coordinator.session
        if let dev = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: dev), session.canAddInput(input) {
            session.addInput(input)
            let out = AVCaptureMetadataOutput()
            if session.canAddOutput(out) {
                session.addOutput(out)
                out.setMetadataObjectsDelegate(context.coordinator, queue: .main)
                out.metadataObjectTypes = [.qr]
            }
        }
        v.preview.session = session
        v.preview.videoGravity = .resizeAspectFill
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        return v
    }

    func updateUIView(_ v: PreviewView, context: Context) {}

    static func dismantleUIView(_ v: PreviewView, coordinator: Coordinator) {
        let s = coordinator.session
        DispatchQueue.global().async { s.stopRunning() }
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let session = AVCaptureSession()
        let onCode: (String) -> Void
        private var done = false
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }

        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput objects: [AVMetadataObject], from connection: AVCaptureConnection) {
            guard !done, let text = (objects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
            done = true
            onCode(text)
        }
    }
}

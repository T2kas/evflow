import SwiftUI
import AVFoundation

/// Back camera via AVFoundation. In the Simulator (no camera) a demo frame is used instead.
final class CameraModel: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var onPhoto: ((UIImage) -> Void)?
    @Published var available = false

    func start() {
        #if targetEnvironment(simulator)
        available = false
        #else
        AVCaptureDevice.requestAccess(for: .video) { ok in
            guard ok else { return }
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in self?.configure() }
        }
        #endif
    }

    private func configure() {
        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam) else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        if session.canAddInput(input) { session.addInput(input) }
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        session.startRunning()
        DispatchQueue.main.async { self.available = true }
    }

    func stop() { DispatchQueue.global().async { [session] in if session.isRunning { session.stopRunning() } } }

    func capture(_ done: @escaping (UIImage) -> Void) {
        guard available else { done(UIImage(named: "demo_report_photo") ?? UIImage()); return }
        onPhoto = done
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let d = photo.fileDataRepresentation(), let img = UIImage(data: d) else { return }
        DispatchQueue.main.async { self.onPhoto?(img) }
    }
}

private struct PreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession
    final class V: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
    func makeUIView(context: Context) -> V {
        let v = V(); v.preview.session = session; v.preview.videoGravity = .resizeAspectFill; return v
    }
    func updateUIView(_ v: V, context: Context) {}
}

/// Full-screen camera → review → sending → done, all in one minimal flow.
/// `onFinish(points)` – nil when cancelled.
struct CameraScreen: View {
    let report: ReportSummary
    let onFinish: (Int?) -> Void

    enum Phase { case live, review, sending, done }
    @StateObject private var cam = CameraModel()
    @State private var phase: Phase = .live
    @State private var shot: UIImage?
    @State private var flash = false
    @State private var checks = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // full-bleed view; dims & blurs slightly once we leave the live camera
            Color.clear
                .overlay {
                    if let shot { Image(uiImage: shot).resizable().scaledToFill() }
                    else if cam.available { PreviewLayer(session: cam.session) }
                    else { Image("demo_report_photo").resizable().scaledToFill() }
                }
                .clipped()
                .blur(radius: phase == .live ? 0 : 6)
                .overlay(Color.black.opacity(phase == .live ? 0 : 0.35))
                .ignoresSafeArea()

            // top bar
            VStack {
                HStack {
                    if phase != .done {
                        Button { cam.stop(); onFinish(nil) } label: {
                            Icon("x", size: 20, color: .white).frame(width: 44, height: 44).background(Circle().fill(.black.opacity(0.35)))
                        }
                    } else { Color.clear.frame(width: 44, height: 44) }
                    Spacer()
                    Text(report.kind).font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .padding(.horizontal, 14).frame(height: 36).background(Capsule().fill(.black.opacity(0.35)))
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 16).padding(.top, 8)
                Spacer()
            }

            // live: hint + blue shutter
            if phase == .live {
                VStack(spacing: 18) {
                    Spacer()
                    Text("Nufotografuokite vietą ir automobilį").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.5), radius: 4)
                    Button(action: takePhoto) {
                        // app-blue square with a same-colour outer stroke
                        ZStack {
                            RoundedRectangle(cornerRadius: 19, style: .continuous).stroke(Color(hex: 0x47a3ff), lineWidth: 3)
                                .frame(width: 80, height: 80)
                            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(hex: 0x47a3ff))
                                .frame(width: 71, height: 71)
                        }
                    }
                    .buttonStyle(ShutterStyle())
                    .padding(.bottom, 20)
                }
                .transition(.opacity)
            }

            // review / sending / done: one white card sliding up from the bottom
            if phase != .live {
                VStack { Spacer(); card }
                    .transition(.move(edge: .bottom))
            }

            Color.white.opacity(flash ? 0.9 : 0).ignoresSafeArea().allowsHitTesting(false)
        }
        .statusBarHidden()
        .onAppear {
            cam.start()
            // demo hooks for screenshots: -demoScreen cameraReview | cameraDone
            let d = UserDefaults.standard.string(forKey: "demoScreen") ?? ""
            if d.hasPrefix("camera"), d != "camera" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { takePhoto() }
                if d == "cameraDone" { DispatchQueue.main.asyncAfter(deadline: .now() + 2) { send() } }
            }
        }
        .onDisappear { cam.stop() }
    }

    // MARK: card

    var card: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule().fill(Color(hex: 0xc4c7cb)).frame(width: 36, height: 4).frame(maxWidth: .infinity).padding(.top, 8).padding(.bottom, 14)

            switch phase {
            case .done:
                VStack(spacing: 6) {
                    Image("ill_report_done").resizable().scaledToFit().frame(height: 150)
                    Text("Ačiū! Pranešimas išsiųstas").font(.system(size: 21, weight: .bold)).padding(.top, 4)
                    Text("\(report.op) jau gavo nuotrauką ir laiką.").font(.system(size: 14)).foregroundStyle(W.text2)
                    Text("+\(report.points) taškų").font(.system(size: 17, weight: .bold)).foregroundStyle(W.blueText)
                        .padding(.horizontal, 16).frame(height: 36).background(Capsule().fill(Color(hex: 0xe6f1ff)))
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
                Button("Grįžti į žemėlapį") { onFinish(report.points) }
                    .buttonStyle(PillButtonStyle()).padding(.top, 20)

            case .sending:
                HStack(spacing: 14) {
                    Image("ill_report_send").resizable().scaledToFit().frame(width: 84, height: 84)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Siunčiama…").font(.system(size: 20, weight: .bold))
                        Text("Tikriname su realaus laiko duomenimis").font(.system(size: 14)).foregroundStyle(W.text2)
                    }
                    Spacer(minLength: 0)
                }
                VStack(spacing: 0) {
                    step(1, icon: report.confirms ? "check" : "lightbulb", color: report.confirms ? W.green : W.grey,
                         title: report.confirms ? "Patvirtinta duomenimis" : "Duomenys to neparodo", text: report.dataText)
                    step(2, icon: "users", color: W.blue, title: "2 vairuotojai šalia patvirtino", text: "Išsiųsta netoliese esantiems EVFlow vartotojams")
                    step(3, icon: "send", color: W.purple, title: "Perduota operatoriui", text: "\(report.op) gavo pranešimą")
                }
                .padding(.top, 8)

            default:
                // review: the shot, what it is and where
                if let shot {
                    Image(uiImage: shot).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: 340)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            HStack(spacing: 6) {
                                Image(report.icon).resizable().scaledToFit().frame(width: 18, height: 18)
                                Text(report.kind).font(.system(size: 14, weight: .semibold))
                            }
                            .padding(.horizontal, 10).frame(height: 32)
                            .background(Capsule().fill(.white))
                            .padding(10)
                        }
                }
                Text(report.station).font(.system(size: 17, weight: .bold)).lineLimit(1).padding(.top, 14)
                HStack(spacing: 12) {
                    Button("Pakartoti") { retake() }.buttonStyle(PillButtonStyle(kind: .secondary))
                    Button("Siųsti pranešimą") { send() }.buttonStyle(PillButtonStyle())
                }
                .padding(.top, 18)
            }
        }
        .padding(.horizontal, 16).padding(.bottom, 10)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous).fill(.white)
                .ignoresSafeArea(edges: .bottom)
        )
        .animation(.snappy(duration: 0.35), value: phase)
    }

    func step(_ n: Int, icon: String, color: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle().fill(color.opacity(0.14)).frame(width: 30, height: 30).overlay(Icon(icon, size: 16, color: color))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(text).font(.system(size: 13)).foregroundStyle(W.text2).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .opacity(checks >= n ? 1 : 0)
        .offset(y: checks >= n ? 0 : 8)
    }

    // MARK: actions

    func takePhoto() {
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { withAnimation(.easeIn(duration: 0.3)) { flash = false } }
        cam.capture { img in
            shot = img
            withAnimation(.snappy(duration: 0.35).delay(0.15)) { phase = .review }
        }
    }

    func retake() {
        withAnimation(.snappy(duration: 0.3)) { phase = .live; shot = nil }
    }

    func send() {
        checks = 0
        withAnimation(.snappy) { phase = .sending }
        for (i, ms) in [450, 1150, 1850].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(ms)) { withAnimation(.easeOut(duration: 0.3)) { checks = i + 1 } }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.7) { withAnimation(.spring(duration: 0.45)) { phase = .done } }
    }
}

private struct ShutterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed ? 0.9 : 1).animation(.spring(duration: 0.18), value: configuration.isPressed)
    }
}

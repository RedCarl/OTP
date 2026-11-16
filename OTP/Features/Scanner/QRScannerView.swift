import SwiftUI
import AVFoundation
import VisionKit

/// Live QR scanning via VisionKit's DataScannerViewController.
struct QRScannerView: View {
    let onPayload: (String) -> Void
    /// When the caller wants to handle dismissal itself.
    var onScanned: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var failureMessage: String?
    @State private var cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)

    private var isCameraAvailable: Bool {
        cameraPermission == .authorized
            && DataScannerViewController.isSupported
            && DataScannerViewController.isAvailable
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if isCameraAvailable {
                    QRScannerRepresentable(
                        onPayload: { payload in
                            if let onScanned {
                                onScanned(payload)
                            } else {
                                onPayload(payload)
                            }
                            dismiss()
                        },
                        onFailure: { message in
                            failureMessage = message
                        }
                    )
                    .ignoresSafeArea()
                } else {
                    unavailableContent
                }

                if let failureMessage {
                    Text(failureMessage)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .padding(24)
                }
            }
            .navigationTitle("扫描二维码")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .task {
                guard cameraPermission == .notDetermined else { return }
                _ = await AVCaptureDevice.requestAccess(for: .video)
                cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
            }
        }
    }

    private var unavailableContent: some View {
        VStack(spacing: 14) {
            Image(systemName: "camera.metering.unknown")
                .font(.system(size: 44))
                .foregroundStyle(.white.opacity(0.7))
            Text(cameraPermission == .denied || cameraPermission == .restricted
                 ? "相机权限已关闭"
                 : "这台设备暂时无法使用相机扫码")
                .font(.headline)
                .foregroundStyle(.white)
            Text(cameraPermission == .denied || cameraPermission == .restricted
                 ? "请到系统设置里允许 OTP 使用相机，或返回改用相册图片 / 粘贴链接。"
                 : "可以返回后从相册选择二维码图片，或直接粘贴 otpauth 链接。")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
            if cameraPermission == .denied {
                Button("打开系统设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            if cameraPermission == .denied {
                Button("关闭") { dismiss() }
                    .buttonStyle(.bordered)
                    .padding(.top, 4)
            } else {
                Button("关闭") { dismiss() }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
            }
        }
    }
}

private struct QRScannerRepresentable: UIViewControllerRepresentable {
    let onPayload: (String) -> Void
    let onFailure: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerHostController {
        let controller = ScannerHostController()
        controller.onPayload = { payload in
            context.coordinator.handle(payload)
        }
        controller.onFailure = onFailure
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerHostController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPayload: onPayload)
    }

    final class Coordinator {
        private let onPayload: (String) -> Void
        private var hasDelivered = false

        init(onPayload: @escaping (String) -> Void) {
            self.onPayload = onPayload
        }

        func handle(_ payload: String) {
            guard !hasDelivered else { return }
            hasDelivered = true
            onPayload(payload)
        }
    }
}

/// Hosts VisionKit's scanner as a child view controller because
/// DataScannerViewController cannot be subclassed outside its module.
private final class ScannerHostController: UIViewController, DataScannerViewControllerDelegate {
    var onPayload: ((String) -> Void)?
    var onFailure: ((String) -> Void)?

    private lazy var scanner: DataScannerViewController = {
        DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
    }()

    private var isRunning = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        scanner.delegate = self

        addChild(scanner)
        scanner.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scanner.view)
        NSLayoutConstraint.activate([
            scanner.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scanner.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scanner.view.topAnchor.constraint(equalTo: view.topAnchor),
            scanner.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !isRunning else { return }
        do {
            try scanner.startScanning()
            isRunning = true
        } catch {
            onFailure?("无法启动相机，请检查相机权限后重试。")
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if isRunning {
            scanner.stopScanning()
            isRunning = false
        }
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
        deliver(from: addedItems)
    }

    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
        if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
            onPayload?(payload)
        }
    }

    private func deliver(from items: [RecognizedItem]) {
        for item in items {
            if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                onPayload?(payload)
                if isRunning {
                    scanner.stopScanning()
                    isRunning = false
                }
                return
            }
        }
    }
}
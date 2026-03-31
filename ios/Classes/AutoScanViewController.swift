import AVFoundation
import UIKit
import Vision
import CoreImage

@available(iOS 13.0, *)
// Custom single-picture scanner used by getScannedDocumentAsImages when
// useAutomaticSinglePictureProcessing is enabled.
final class AutoScanViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    enum ScannerError: LocalizedError {
        case cameraUnavailable
        case cameraInputUnavailable
        case cameraPermissionDenied
        case imageEncodingFailed

        var errorDescription: String? {
            switch self {
            case .cameraUnavailable:
                return "Back camera is unavailable on this device."
            case .cameraInputUnavailable:
                return "Unable to configure camera input or output."
            case .cameraPermissionDenied:
                return "Camera permission was denied."
            case .imageEncodingFailed:
                return "Unable to create image data from camera capture."
            }
        }
    }

    var onImageCaptured: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?
    var onError: ((Error) -> Void)?

    private let captureSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.flutter_doc_scanner.autoscan.session")
    private let processingQueue = DispatchQueue(label: "com.flutter_doc_scanner.autoscan.processing")
    private let photoOutput = AVCapturePhotoOutput()
    private let ciContext = CIContext()

    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasConfiguredSession = false
    private var isCapturingPhoto = false

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle("Cancel", for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        button.layer.cornerRadius = 18
        button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
        button.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .custom)
        button.backgroundColor = .white
        button.layer.cornerRadius = 34
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.black.withAlphaComponent(0.20).cgColor
        button.addTarget(self, action: #selector(captureTapped), for: .touchDown)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation {
        .portrait
    }

    override var shouldAutorotate: Bool {
        false
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        view.addSubview(cancelButton)
        view.addSubview(captureButton)

        NSLayoutConstraint.activate([
            cancelButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            cancelButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            captureButton.widthAnchor.constraint(equalToConstant: 68),
            captureButton.heightAnchor.constraint(equalToConstant: 68)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        if let previewConnection = previewLayer?.connection,
           previewConnection.isVideoOrientationSupported {
            previewConnection.videoOrientation = .portrait
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startScannerIfNeeded()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    @objc
    private func cancelTapped() {
        dismissScanner { [weak self] in
            self?.onCancel?()
        }
    }

    @objc
    private func captureTapped() {
        guard !isCapturingPhoto else { return }
        isCapturingPhoto = true
        captureButton.isEnabled = false
        cancelButton.isEnabled = false
        freezePreviewImmediately()
        capturePhoto()
    }

    private func startScannerIfNeeded() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndStartSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if granted {
                        self.configureAndStartSession()
                    } else {
                        self.failAndDismiss(ScannerError.cameraPermissionDenied)
                    }
                }
            }
        default:
            failAndDismiss(ScannerError.cameraPermissionDenied)
        }
    }

    private func configureAndStartSession() {
        if hasConfiguredSession {
            startSession()
            return
        }

        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                try self.configureCaptureSession()
                self.hasConfiguredSession = true
                self.captureSession.startRunning()
            } catch {
                DispatchQueue.main.async {
                    self.failAndDismiss(error)
                }
            }
        }
    }

    private func configureCaptureSession() throws {
        captureSession.beginConfiguration()
        captureSession.sessionPreset = .high
        defer { captureSession.commitConfiguration() }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw ScannerError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard captureSession.canAddInput(input) else {
            throw ScannerError.cameraInputUnavailable
        }
        captureSession.addInput(input)

        guard captureSession.canAddOutput(photoOutput) else {
            throw ScannerError.cameraInputUnavailable
        }
        captureSession.addOutput(photoOutput)
        photoOutput.isHighResolutionCaptureEnabled = false

        if let photoConnection = photoOutput.connection(with: .video),
           photoConnection.isVideoOrientationSupported {
            photoConnection.videoOrientation = .portrait
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let preview = AVCaptureVideoPreviewLayer(session: self.captureSession)
            preview.videoGravity = .resizeAspectFill
            preview.frame = self.view.bounds
            self.view.layer.insertSublayer(preview, at: 0)
            self.previewLayer = preview
        }
    }

    private func startSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    private func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
            }
        }
    }

    private func dismissScanner(animated: Bool = true, completion: @escaping () -> Void) {
        stopSession()
        dismiss(animated: animated, completion: completion)
    }

    private func failAndDismiss(_ error: Error) {
        dismissScanner { [weak self] in
            self?.onError?(error)
        }
    }

    private func capturePhoto() {
        let settings: AVCapturePhotoSettings
        if photoOutput.availablePhotoCodecTypes.contains(.jpeg) {
            settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        } else {
            settings = AVCapturePhotoSettings()
        }
        settings.isHighResolutionPhotoEnabled = false
        settings.photoQualityPrioritization = .speed

        if let connection = photoOutput.connection(with: .video),
           connection.isVideoOrientationSupported {
            connection.videoOrientation = .portrait
        }

        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            failAndDismiss(error)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            failAndDismiss(ScannerError.imageEncodingFailed)
            return
        }

        dismissScanner(animated: false) { [self] in
            processAndDeliverCapturedImage(image)
        }
    }

    private func processAndDeliverCapturedImage(_ image: UIImage) {
        processingQueue.async { [self] in
            let processedImage = prepareSingleImage(image, maxDimension: 1280)
            DispatchQueue.main.async {
                self.onImageCaptured?(processedImage)
            }
        }
    }

    private func prepareSingleImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let normalizedImage = normalizedUprightImage(image)
        // Keep detection fast by limiting input size.
        let detectionInput = resizedImageIfNeeded(normalizedImage, maxDimension: 1600)
        let croppedImage = detectAndCropDocument(detectionInput) ?? detectionInput
        let portraitImage = forcePortraitOrientation(croppedImage)
        return resizedImageIfNeeded(portraitImage, maxDimension: maxDimension)
    }

    private func normalizedUprightImage(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        let renderer = UIGraphicsImageRenderer(size: image.size)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    private func forcePortraitOrientation(_ image: UIImage) -> UIImage {
        guard image.size.width > image.size.height else {
            return image
        }

        let targetSize = CGSize(width: image.size.height, height: image.size.width)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            let context = UIGraphicsGetCurrentContext()
            context?.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
            context?.rotate(by: -.pi / 2)
            image.draw(
                in: CGRect(
                    x: -image.size.width / 2,
                    y: -image.size.height / 2,
                    width: image.size.width,
                    height: image.size.height
                )
            )
        }
    }

    private func resizedImageIfNeeded(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let currentMax = max(image.size.width, image.size.height)
        guard currentMax > maxDimension else { return image }

        let scale = maxDimension / currentMax
        let targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func detectAndCropDocument(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)

        let request = VNDetectRectanglesRequest()
        request.maximumObservations = 1
        request.minimumConfidence = 0.7
        request.minimumSize = 0.2
        request.minimumAspectRatio = 0.3
        request.quadratureTolerance = 20.0

        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }

        guard let observation = (request.results as? [VNRectangleObservation])?.first else {
            return nil
        }

        let extent = ciImage.extent
        func denormalize(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: extent.origin.x + point.x * extent.width,
                y: extent.origin.y + point.y * extent.height
            )
        }

        guard let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") else {
            return nil
        }
        perspectiveFilter.setValue(ciImage, forKey: kCIInputImageKey)
        perspectiveFilter.setValue(CIVector(cgPoint: denormalize(observation.topLeft)), forKey: "inputTopLeft")
        perspectiveFilter.setValue(CIVector(cgPoint: denormalize(observation.topRight)), forKey: "inputTopRight")
        perspectiveFilter.setValue(CIVector(cgPoint: denormalize(observation.bottomRight)), forKey: "inputBottomRight")
        perspectiveFilter.setValue(CIVector(cgPoint: denormalize(observation.bottomLeft)), forKey: "inputBottomLeft")

        guard let outputImage = perspectiveFilter.outputImage,
              let outputCGImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else {
            return nil
        }

        return UIImage(cgImage: outputCGImage)
    }

    private func freezePreviewImmediately() {
        if let previewConnection = previewLayer?.connection {
            previewConnection.isEnabled = false
        }
    }
}

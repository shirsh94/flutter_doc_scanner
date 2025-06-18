import UIKit
import AVFoundation

@available(iOS 13.0, *)
class ManualDocumentScannerViewController: UIViewController {

    var captureSession: AVCaptureSession!
    var photoOutput: AVCapturePhotoOutput!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var capturedImages: [UIImage] = []

    var onCaptureComplete: (([UIImage]) -> Void)?

    private let shutterButton: UIButton = {
        let button = UIButton(type: .custom)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = .white
        button.layer.cornerRadius = 35
        button.layer.borderColor = UIColor.black.cgColor
        button.layer.borderWidth = 3
        return button
    }()

    private let doneButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("Done", for: .normal)
        button.setTitleColor(.white, for: .normal)
        return button
    }()

    private let flashButton: UIButton = {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("⚡️", for: .normal)
        button.setTitleColor(.white, for: .normal)
        return button
    }()

    var isFlashOn = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
        setupUI()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .photo

        guard let backCamera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: backCamera),
              captureSession.canAddInput(input)
        else {
            print("Unable to access back camera!")
            return
        }

        captureSession.addInput(input)

        photoOutput = AVCapturePhotoOutput()
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.insertSublayer(previewLayer, at: 0)

        captureSession.startRunning()
    }

    private func setupUI() {
        view.addSubview(shutterButton)
        view.addSubview(doneButton)
        view.addSubview(flashButton)

        NSLayoutConstraint.activate([
            shutterButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            shutterButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -60),
            shutterButton.widthAnchor.constraint(equalToConstant: 70),
            shutterButton.heightAnchor.constraint(equalToConstant: 70),

            doneButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            doneButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),

            flashButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            flashButton.topAnchor.constraint(equalTo: view.topAnchor, constant: 40),
        ])

        shutterButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        doneButton.addTarget(self, action: #selector(finishCapture), for: .touchUpInside)
        flashButton.addTarget(self, action: #selector(toggleFlash), for: .touchUpInside)
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        settings.flashMode = isFlashOn ? .on : .off
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    @objc private func toggleFlash() {
        isFlashOn.toggle()
        flashButton.setTitle(isFlashOn ? "⚡️ On" : "⚡️ Off", for: .normal)
    }

    @objc private func finishCapture() {
        captureSession.stopRunning()
        dismiss(animated: true) {
            self.onCaptureComplete?(self.capturedImages)
        }
    }
}

extension ManualDocumentScannerViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        if let data = photo.fileDataRepresentation(),
           let image = UIImage(data: data) {
            capturedImages.append(image)
        }
    }
}

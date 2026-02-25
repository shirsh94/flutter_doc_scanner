import Flutter
import UIKit
import VisionKit
import PDFKit
import AVFoundation

@available(iOS 13.0, *)
public class SwiftFlutterDocScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
    private var resultChannel: FlutterResult?
    private weak var presentingController: VNDocumentCameraViewController?
    private var currentMethod: String?
    private var currentImageFormat: String = "jpeg"
    private var currentQuality: CGFloat = 0.9
    private var isScanInProgress: Bool = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_doc_scanner", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterDocScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getPlatformVersion":
            result("iOS " + UIDevice.current.systemVersion)
        case "getScanDocuments", "getScannedDocumentAsImages", "getScannedDocumentAsPdf":
            let args = call.arguments as? [String: Any]
            let imageFormat = args?["imageFormat"] as? String ?? "jpeg"
            let quality = args?["quality"] as? Double ?? 0.9
            startScan(method: call.method, imageFormat: imageFormat, quality: quality, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func startScan(method: String, imageFormat: String, quality: Double, result: @escaping FlutterResult) {
        if isScanInProgress {
            result(FlutterError(code: "SCAN_IN_PROGRESS", message: "Another scan is already running", details: nil))
            return
        }

        guard VNDocumentCameraViewController.isSupported else {
            result(FlutterError(code: "UNSUPPORTED", message: "Document scanning is not supported on this device", details: nil))
            return
        }

        checkCameraPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if granted {
                    self.presentScanner(method: method, imageFormat: imageFormat, quality: quality, result: result)
                } else {
                    result(FlutterError(code: "PERMISSION_DENIED", message: "Camera permission is required for document scanning", details: nil))
                }
            }
        }
    }

    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        default:
            completion(false)
        }
    }

    private func presentScanner(method: String, imageFormat: String, quality: Double, result: @escaping FlutterResult) {
        guard let rootVC = self.getRootViewController() else {
            result(FlutterError(code: "NO_VIEW_CONTROLLER", message: "Unable to find a view controller to present the scanner", details: nil))
            return
        }

        self.isScanInProgress = true
        self.resultChannel = result
        self.currentMethod = method
        self.currentImageFormat = imageFormat
        self.currentQuality = CGFloat(max(0.0, min(1.0, quality)))

        let scanner = VNDocumentCameraViewController()
        scanner.delegate = self
        self.presentingController = scanner
        rootVC.present(scanner, animated: true)
    }

    private func getRootViewController() -> UIViewController? {
        if #available(iOS 15.0, *) {
            let scene = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first
            return scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
        } else {
            return UIApplication.shared.keyWindow?.rootViewController
        }
    }

    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func finishWithResult(_ value: Any?) {
        resultChannel?(value)
        cleanup()
    }

    private func finishWithError(code: String, message: String, details: String? = nil) {
        resultChannel?(FlutterError(code: code, message: message, details: details))
        cleanup()
    }

    private func cleanup() {
        resultChannel = nil
        currentMethod = nil
        currentImageFormat = "jpeg"
        currentQuality = 0.9
        isScanInProgress = false
    }

    // MARK: - VNDocumentCameraViewControllerDelegate

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        controller.dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            switch self.currentMethod {
            case "getScanDocuments", "getScannedDocumentAsImages":
                self.saveScannedImages(scan: scan)
            case "getScannedDocumentAsPdf":
                self.saveScannedPdf(scan: scan)
            default:
                self.finishWithResult(nil)
            }
        }
    }

    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) { [weak self] in
            self?.finishWithResult(nil)
        }
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        controller.dismiss(animated: true) { [weak self] in
            self?.finishWithError(code: "SCAN_FAILED", message: "Failed to scan documents", details: error.localizedDescription)
        }
    }

    // MARK: - File saving

    private func saveScannedImages(scan: VNDocumentCameraScan) {
        let tempDirPath = getDocumentsDirectory()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let formattedDate = df.string(from: Date())
        let useJpeg = currentImageFormat == "jpeg"
        let ext = useJpeg ? "jpg" : "png"
        var filenames: [String] = []

        for i in 0 ..< scan.pageCount {
            let page = scan.imageOfPage(at: i)
            let url = tempDirPath.appendingPathComponent("\(formattedDate)-\(i).\(ext)")
            let imageData: Data?
            if useJpeg {
                imageData = page.jpegData(compressionQuality: currentQuality)
            } else {
                imageData = page.pngData()
            }
            guard let data = imageData else {
                finishWithError(code: "IMAGE_ENCODING_ERROR", message: "Failed to encode page \(i) as \(ext.uppercased())")
                cleanupFiles(filenames)
                return
            }
            do {
                try data.write(to: url)
                filenames.append(url.path)
            } catch {
                finishWithError(code: "FILE_WRITE_ERROR", message: "Failed to save scanned image", details: error.localizedDescription)
                cleanupFiles(filenames)
                return
            }
        }
        finishWithResult(filenames)
    }

    private func saveScannedPdf(scan: VNDocumentCameraScan) {
        let tempDirPath = getDocumentsDirectory()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let formattedDate = df.string(from: Date())
        let pdfFilePath = tempDirPath.appendingPathComponent("\(formattedDate).pdf")

        let pdfDocument = PDFDocument()
        for i in 0 ..< scan.pageCount {
            let pageImage = scan.imageOfPage(at: i)
            guard let pdfPage = PDFPage(image: pageImage) else {
                finishWithError(code: "PDF_CREATION_ERROR", message: "Failed to create PDF page from scanned image at index \(i)")
                return
            }
            pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
        }

        guard pdfDocument.write(to: pdfFilePath) else {
            try? FileManager.default.removeItem(at: pdfFilePath)
            finishWithError(code: "PDF_CREATION_ERROR", message: "Failed to write PDF to disk")
            return
        }
        finishWithResult(pdfFilePath.path)
    }

    private func cleanupFiles(_ paths: [String]) {
        for path in paths {
            try? FileManager.default.removeItem(atPath: path)
        }
    }
}

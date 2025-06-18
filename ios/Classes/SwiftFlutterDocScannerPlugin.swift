import Flutter
import UIKit
import Vision
import VisionKit
import PDFKit

@available(iOS 13.0, *)
public class SwiftFlutterDocScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {

    var resultChannel: FlutterResult?
    var currentMethod: String?
    var presentingController: UIViewController?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_doc_scanner", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterDocScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        self.resultChannel = result
        self.currentMethod = call.method

        guard let rootVC = UIApplication.shared.connectedScenes
                .compactMap({ ($0 as? UIWindowScene)?.keyWindow })
                .first?.rootViewController else {
            result(FlutterError(code: "NO_UI", message: "Unable to access root view controller", details: nil))
            return
        }

        if call.method == "manualScan" {
            let manualVC = ManualDocumentScannerViewController()
            manualVC.modalPresentationStyle = .fullScreen

            manualVC.onCaptureComplete = { images in
                let tempDir = FileManager.default.temporaryDirectory
                var paths: [String] = []

                for (i, image) in images.enumerated() {
                    if let data = image.jpegData(compressionQuality: 0.8) {
                        let url = tempDir.appendingPathComponent("scan_\(UUID().uuidString)_\(i).jpg")
                        try? data.write(to: url)
                        paths.append(url.path)
                    }
                }

                if paths.isEmpty {
                    result(FlutterError(code: "CAPTURE_ERROR", message: "No images captured", details: nil))
                } else {
                    result(paths)
                }
            }

            rootVC.present(manualVC, animated: true)

        } else if ["getScanDocuments", "getScannedDocumentAsImages", "getScannedDocumentAsPdf"].contains(call.method) {
            let docScanner = VNDocumentCameraViewController()
            docScanner.delegate = self
            self.presentingController = rootVC
            rootVC.present(docScanner, animated: true)

        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    private func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }

    // MARK: - VNDocumentCameraViewControllerDelegate

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        switch currentMethod {
        case "getScanDocuments", "getScannedDocumentAsImages":
            saveScannedImages(scan: scan)
        case "getScannedDocumentAsPdf":
            saveScannedPdf(scan: scan)
        default:
            resultChannel?(FlutterError(code: "INVALID_METHOD", message: "Unsupported scan method", details: nil))
        }
        presentingController?.dismiss(animated: true)
    }

    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        resultChannel?(nil)
        presentingController?.dismiss(animated: true)
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        resultChannel?(FlutterError(code: "SCAN_ERROR", message: "Scan failed", details: error.localizedDescription))
        presentingController?.dismiss(animated: true)
    }

    // MARK: - Save Functions

    private func saveScannedImages(scan: VNDocumentCameraScan) {
        let tempDirPath = getDocumentsDirectory()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let formattedDate = df.string(from: Date())

        var filenames: [String] = []

        for i in 0..<scan.pageCount {
            let page = scan.imageOfPage(at: i)
            let url = tempDirPath.appendingPathComponent("\(formattedDate)-\(i).png")
            try? page.pngData()?.write(to: url)
            filenames.append(url.path)
        }

        resultChannel?(filenames)
    }

    private func saveScannedPdf(scan: VNDocumentCameraScan) {
        let tempDirPath = getDocumentsDirectory()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let formattedDate = df.string(from: Date())

        let pdfFilePath = tempDirPath.appendingPathComponent("\(formattedDate).pdf")
        let pdfDocument = PDFDocument()

        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            if let pdfPage = PDFPage(image: image) {
                pdfDocument.insert(pdfPage, at: pdfDocument.pageCount)
            }
        }

        do {
            try pdfDocument.write(to: pdfFilePath)
            resultChannel?(pdfFilePath.path)
        } catch {
            resultChannel?(FlutterError(code: "PDF_CREATION_ERROR", message: "Could not create PDF", details: error.localizedDescription))
        }
    }
}

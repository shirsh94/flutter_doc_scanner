enum VisionResult{
    case success( images:[UIImage])
    case canceled
}

typealias VisionHandler = (Result<VisionResult,Error>) -> Void

import VisionKit
class IOSDocScannerController: NSObject, VNDocumentCameraViewControllerDelegate {
    let visionController = VNDocumentCameraViewController()
    var completionHandler: VisionHandler?
    override init() {
        super.init()
        visionController.delegate = self
        visionController.modalPresentationStyle = UIModalPresentationStyle.currentContext
    }
    func pickDocument(completionHandler: @escaping VisionHandler){
        self.completionHandler = completionHandler
        self.viewControllerWithWindow(window: nil)?.present(self.visionController, animated:true)
    }

    private func viewControllerWithWindow(window:UIWindow?) ->UIViewController?{
        var windowToUse = window
        if(windowToUse == nil){
            for  keyWindow in UIApplication.shared.windows{
                if(keyWindow.isKeyWindow){
                    windowToUse = keyWindow
                    break
                }
            }
        }
        var topController = windowToUse!.rootViewController;
        while topController?.presentedViewController != nil {
            topController = topController?.presentedViewController
        }
        return topController
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        var images:[UIImage] = []
        for i in 0 ..< scan.pageCount {
            images.append(scan.imageOfPage(at: i))
           }
        visionController.dismiss(animated: true, completion: nil)
        self.completionHandler?(.success(VisionResult.success(images:images )))
    }
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        visionController.dismiss(animated: true, completion: nil)
        self.completionHandler?(.success(.canceled))

    }
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        visionController.dismiss(animated: true, completion: nil)
        self.completionHandler?(.failure(error))
    }
}
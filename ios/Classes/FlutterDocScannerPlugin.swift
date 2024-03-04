import Flutter
import UIKit

public class FlutterDocScannerPlugin: NSObject, FlutterPlugin {
  var visionController:IOSDocScannerController?
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_doc_scanner", binaryMessenger: registrar.messenger())
    let instance = FlutterDocScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

   public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
          if (call.method != "getScanDocuments"){
              result(FlutterError(code: "not_implemented", message: "\(call.method) is not implemented", details: nil))
              return
          }
          #if targetEnvironment(simulator)
          result(FlutterError(code: "not_implemented", message: "Can not run on Simulator", details: nil))
          return
          #else
          visionController = IOSDocScannerController()
          visionController?.getScanDocuments{ [weak self] pickerResult in
              guard let self = self else { return }

              switch(pickerResult){
              case .success(let pickerResult):
                  switch pickerResult {
                  case .success(images: let images):
                      self.saveImaged(images: images, result: result)
                  case .canceled:
                      result(nil)
                  }
              case .failure(let error):
                  result(FlutterError(code: "code", message: error.localizedDescription, details: nil))
              }
          }
          #endif
      }
      private func saveImaged(images:[UIImage], result: @escaping FlutterResult){
          DispatchQueue.global(qos: .userInitiated).async {
              let tempDirUrl = NSURL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

              var imagePaths:[String] = []
              for image in images {
                  let uuid = UUID().uuidString
                  if let data = image.pngData(), let tempFileURL = tempDirUrl.appendingPathComponent("vision_kit_\(uuid).png"){
                      do{
                          try data.write(to: tempFileURL)
                          imagePaths.append(tempFileURL.absoluteString)
                      }catch let error{
                          result(FlutterError(code: "create_file_error", message: error.localizedDescription, details: nil))
                      }

                  }
              }
              DispatchQueue.main.async {
                  result(imagePaths)
              }
          }
      }
  }
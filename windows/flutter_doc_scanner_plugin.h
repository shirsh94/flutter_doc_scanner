#ifndef FLUTTER_PLUGIN_FLUTTER_DOC_SCANNER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_DOC_SCANNER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_doc_scanner {

class FlutterDocScannerPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterDocScannerPlugin();

  virtual ~FlutterDocScannerPlugin();

  // Disallow copy and assign.
  FlutterDocScannerPlugin(const FlutterDocScannerPlugin&) = delete;
  FlutterDocScannerPlugin& operator=(const FlutterDocScannerPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_doc_scanner

#endif  // FLUTTER_PLUGIN_FLUTTER_DOC_SCANNER_PLUGIN_H_

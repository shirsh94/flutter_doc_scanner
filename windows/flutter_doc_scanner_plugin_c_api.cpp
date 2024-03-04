#include "include/flutter_doc_scanner/flutter_doc_scanner_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_doc_scanner_plugin.h"

void FlutterDocScannerPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_doc_scanner::FlutterDocScannerPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}

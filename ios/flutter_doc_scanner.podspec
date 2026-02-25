#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_doc_scanner.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_doc_scanner'
  s.version          = '0.0.17'
  s.summary          = 'A Flutter plugin for document scanning using VisionKit.'
  s.description      = <<-DESC
A Flutter plugin for document scanning on iOS using VisionKit with support for
PDF and image output formats.
                       DESC
  s.homepage         = 'https://github.com/shirsh94/flutter_doc_scanner'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Shirsh Shukla' => 'https://medium.com/@shirsh94' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '13.0'
  s.frameworks = 'VisionKit', 'PDFKit', 'AVFoundation'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end

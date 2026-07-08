Pod::Spec.new do |s|
  s.name             = 'Sentinel'
  s.version          = '0.1.3'
  s.summary          = 'Native iOS SDK for the Sentinel identity-verification flow.'
  s.description      = <<-DESC
    Hosts the Sentinel web verification runtime in a WKWebView and adds a native
    layer for camera-permission handling and a typed result callback.
  DESC
  s.homepage         = 'https://github.com/prawatstackflow/sentinel-ios'
  s.license          = { :type => 'Proprietary', :text => 'Copyright Finvasia' }
  s.author           = { 'Finvasia' => 'dev@finvasia.com' }
  s.source           = { :git => 'https://github.com/prawatstackflow/sentinel-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '14.3'
  s.swift_version    = '5.9'
  s.source_files     = 'Sources/Sentinel/**/*.swift'
  s.frameworks       = 'UIKit', 'WebKit'
end

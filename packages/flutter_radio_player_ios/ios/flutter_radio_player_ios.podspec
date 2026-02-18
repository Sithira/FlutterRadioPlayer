Pod::Spec.new do |s|
  s.name             = 'flutter_radio_player_ios'
  s.version          = '4.0.0'
  s.summary          = 'iOS implementation of flutter_radio_player.'
  s.description      = <<-DESC
iOS implementation of the flutter_radio_player plugin using AVFoundation.
                       DESC
  s.homepage         = 'https://github.com/Sithira/FlutterRadioPlayer'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Sithira Munasinghe' => 'sithira@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'flutter_radio_player_ios/Sources/flutter_radio_player_ios/**/*.swift'
  s.dependency 'Flutter'
  s.platform         = :ios, '14.0'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version    = '5.0'
  s.resource_bundles = {'flutter_radio_player_ios_privacy' => ['flutter_radio_player_ios/Sources/flutter_radio_player_ios/PrivacyInfo.xcprivacy']}
end

#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_radio_player.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_radio_player'
  s.version          = '0.0.1'
  s.summary          = 'Online Radio Player for Flutter which enable to play streaming URL. Supports Android and iOS as well as WearOs and watchOs'
  s.description      = <<-DESC
Online Radio Player for Flutter which enable to play streaming URL. Supports Android and iOS as well as WearOs and watchOs
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.dependency 'SwiftAudioEx', '~> 1.1.0'
  s.platform = :ios, '12.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end


#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint live_location_tracker_plus.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'live_location_tracker_plus'
  s.version          = '1.0.0'
  s.summary          = 'A Flutter plugin for live background location tracking with geofencing, Firebase sync, and battery optimization.'
  s.description      = <<-DESC
Live Location Tracker Plus provides real-time background location tracking,
geofence monitoring (enter/exit/dwell), optional Firebase Firestore sync,
and battery-optimized tracking modes for iOS and Android.
                       DESC
  s.homepage         = 'https://github.com/bijoyknath999/live_location_tracker_plus'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Bijoy Kumar Nath' => 'bijoykumarnath999@gmail.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '14.0'
  s.frameworks = 'CoreLocation'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Privacy manifest
  # s.resource_bundles = {'live_location_tracker_plus_privacy' => ['Resources/PrivacyInfo.xcprivacy']}
end

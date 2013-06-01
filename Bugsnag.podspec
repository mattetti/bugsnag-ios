Pod::Spec.new do |s|
  s.name         = "Bugsnag"
  s.version      = "2.2.3"
  s.summary      = "iOS notifier for SDK for bugsnag.com"
  s.homepage     = "https://bugsnag.com"
  s.license      = 'MIT'
  s.author       = { "Bugsnag" => "notifiers@bugsnag.com" }
  s.source       = { :git => "https://github.com/bugsnag/bugsnag-ios.git", :tag => "2.2.3" }
  s.platform     = :ios, '4.0'
  s.source_files = ['Bugsnag Plugin', 'Bugsnag Plugin/Categories']
  s.requires_arc = true

  s.private_header_files = [
    'Bugsnag Plugin/BugsnagPrivate.h',
    'Bugsnag Plugin/BugsnagEvent.h',
    'Bugsnag Plugin/BugsnagMetaData.h',
    'Bugsnag Plugin/BugsnagNotifier.h',
  ]
  s.framework  = 'SystemConfiguration'
  
  s.dependency 'Reachability', '~> 3.1'
end

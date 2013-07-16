Pod::Spec.new do |s|
  s.name         = "Bugsnag"
  s.version      = "2.2.3"
  s.summary      = "iOS/OS X notifier for SDK for bugsnag.com"
  s.homepage     = "https://bugsnag.com"
  s.license      = 'MIT'
  s.author       = { "Bugsnag" => "notifiers@bugsnag.com" }
  s.source       = { :git => "https://github.com/mattetti/bugsnag-ios.git", :branch => "iOS-and-OSX-support" }
  s.ios.deployment_target = '4.0'
  s.osx.deployment_target = '10.7'
  s.source_files = ['Bugsnag Plugin', 'Bugsnag Plugin/Categories']
  s.requires_arc = true

  s.public_header_files = 'Bugsnag Plugin/Bugsnag.h'
  s.framework  = 'SystemConfiguration'
  
  # Finally, specify any Pods that this Pod depends on.
  #
  s.dependency 'Reachability', '~> 3.1'
end

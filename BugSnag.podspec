Pod::Spec.new do |s|
  s.name         = "BugSnag"
  s.version      = "0.0.1"
  s.summary      = "The iOS SDK for BugSnag."
  s.homepage     = "https://bugsnag.com"
  s.license      = 'MIT'
  s.author       = { "BugSnag" => "support@bugsnag.com" }
  s.source       = { :git => "https://github.com/MaxGabriel/bugsnag-ios.git", :commit => "4da6fa80ade3a3f8e514e24d5054b3c5341980f4" }
  s.platform     = :ios, '4.0'
  s.source_files = 'Bugsnag Plugin', 'Unity'

  # s.public_header_files = 'Classes/**/*.h'
  s.framework  = 'SystemConfiguration'
  
  # Finally, specify any Pods that this Pod depends on.
  #
  # s.dependency 'JSONKit', '~> 1.4'
end

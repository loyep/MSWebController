Pod::Spec.new do |s|
  s.name         = "MSWebController"
  s.version      = "1.0.0"
  s.summary      = "MSWebController"
  s.description  = <<-EOS
  MSWebController.
  EOS
  s.homepage     = "https://github.com/MaxseyLau/MSWebController"
  s.license      = "MIT"
  s.author             = { "Maxwell" => "maxwell.me@live.com" }
  s.ios.deployment_target = '7.0'
  s.osx.deployment_target = '10.10'
  s.watchos.deployment_target = '2.0'
  s.tvos.deployment_target = '9.0'
  s.source       = { :git => "https://github.com/MaxseyLau/MSWebController.git", :tag => s.version }
  s.resources = ["Sources/**/*.{bundle}"]
  s.source_files  = "Sources/**/*.{h,m}"
  s.framework  = "UIKit", "Foundation", "WebKit"
  s.requires_arc = true
  
end

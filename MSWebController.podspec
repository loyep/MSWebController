Pod::Spec.new do |s|
  s.name         = "MSWebController"
  s.version      = "1.0.0"
  s.summary      = "MSWebController"
  s.description  = <<-EOS
  MSWebController.
  EOS
  s.homepage     = "https://github.com/MaxseyLau/MSWebController"
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { "Maxwell" => "maxwell.me@live.com" }
  s.platform     = :ios, '7.0'
  s.source       = { :git => "https://github.com/MaxseyLau/MSWebController.git", :tag => s.version.to_s }
  s.resources = ["Sources/**/*.{bundle}"]
  s.source_files  = "Sources/**/*.{h,m}"
  s.framework  = "WebKit"
  s.requires_arc = true
end
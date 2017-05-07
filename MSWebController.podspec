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
  s.ios.deployment_target = '8.0'
  s.osx.deployment_target = '10.10'
  s.watchos.deployment_target = '2.0'
  s.tvos.deployment_target = '9.0'
  s.source       = { :git => "https://github.com/MaxseyLau/MSWebController.git", :tag => s.version }
  s.default_subspec = "Core"
  s.public_header_files = "Sources/MSWebController.h"

  s.subspec "Core" do |ss|
    ss.source_files  = "Sources/Core/"
    ss.framework  = "WebKit"
  end

  # s.subspec "RxSwift" do |ss|
  #   ss.source_files = "Sources/RxSwiftOctoKit/"
  #   ss.dependency "SwiftOctoKit/Core"
  #   ss.dependency "RxSwift", "~> 3.0"
  #   ss.dependency "RxCocoa"
  # end
end

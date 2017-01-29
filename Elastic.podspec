Pod::Spec.new do |s|
  s.name             = "Elastic"
  s.version          = "0.0.1"
  s.summary          = "A Hero plugin that does elastic transition using metal."

  s.description      = <<-DESC
                        A Hero plugin that does elastic transition using metal.
                       DESC

  s.homepage         = "https://github.com/lkzhao/Elastic"
  s.screenshots      = "https://github.com/lkzhao/Elastic/blob/master/Resources/elastic.png?raw=true"
  s.license          = 'MIT'
  s.author           = { "Luke" => "lzhaoyilun@gmail.com" }
  s.source           = { :git => "https://github.com/lkzhao/Elastic.git", :tag => s.version.to_s }
  
  s.ios.deployment_target  = '8.0'
  s.ios.frameworks         = 'UIKit', 'Foundation'

  s.requires_arc = true

  s.source_files = 'Sources/*.swift'
end

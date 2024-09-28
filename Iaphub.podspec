Pod::Spec.new do |s|
  s.name             = 'Iaphub'
  s.version          = '4.3.0'
  s.summary          = 'iOS IAPHUB SDK'

  s.description      = <<-DESC
App developers use IAPHUB to manage their In-App purchases
No more complex backend development to validate receipts, focus on your app instead! (https://www.iaphub.com)
                       DESC

  s.homepage          = 'https://www.iaphub.com'
  s.license           = { :type => 'MIT', :file => 'LICENSE' }
  s.author            = { 'Iaphub' => 'support@iaphub.com' }
  s.source            = { :git => 'https://github.com/iaphub/iaphub-ios-sdk.git', :tag => s.version.to_s }
  s.documentation_url = "https://www.iaphub.com/docs"

  s.ios.deployment_target = '9.0'

  s.swift_versions = ['5.0', '5.1']
  
  s.source_files = ['Iaphub/**/*.{swift}']

  s.resource_bundles = {"Iaphub" => ["Iaphub/PrivacyInfo.xcprivacy"]}

  s.frameworks = 'StoreKit'
end

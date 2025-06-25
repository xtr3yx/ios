# Uncomment the next line to define a global platform for your project
platform :ios, '13.0'

source 'https://cdn.cocoapods.org/'
source 'https://github.com/gonativeio/gonative-specs.git'



require_relative './plugins.rb'

target default_app_target do
  # Comment the next line if you don't want to use dynamic frameworks
  use_frameworks!

  # Pods for GonativeIO
  pod 'GoNativeCore'
  pod 'SSZipArchive'

  use_plugins!

  target 'MedianIOSTests' do
    inherit! :search_paths
    # Pods for testing
  end
end

post_install do |installer|
  # 🔧 Dla podów
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings.delete 'IPHONEOS_DEPLOYMENT_TARGET'
      config.build_settings['BUILD_LIBRARY_FOR_DISTRIBUTION'] = 'YES'
      config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
    end
  end

  # 🔧 Dla głównego projektu
  installer.aggregate_targets.each do |target|
    target.user_project.native_targets.each do |native_target|
      native_target.build_configurations.each do |config|
        config.build_settings['CODE_SIGN_STYLE'] = 'Manual'
        config.build_settings['CODE_SIGNING_REQUIRED'] = 'NO'
        config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
        config.build_settings['DEVELOPMENT_TEAM'] = ''
        config.build_settings['PROVISIONING_PROFILE_SPECIFIER'] = ''
      end
    end
  end
end

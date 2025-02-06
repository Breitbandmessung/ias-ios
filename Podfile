ENV['COCOAPODS_DISABLE_STATS'] = 'true'

# Workaround for problems with new Xcode build system
install! 'cocoapods', :disable_input_output_paths => true

# Uncomment the next line to define a global platform for your project
platform :ios, '14.0'

# ignore all warnings from all pods
inhibit_all_warnings!


target 'Common' do
    use_frameworks!
    pod 'CocoaLumberjack', '>= 3.7.4'
end

target 'Speed' do
    use_frameworks!
    pod 'ias-libtool', :path => 'ias-client-cpp/ias-libtool'
    pod 'ias-client-cpp', :path => 'ias-client-cpp'
    pod 'hpple', '>= 0.2.0'
end

target 'Coverage' do
    use_frameworks!
    pod 'CocoaLumberjack', '>= 3.7.4'
end

target 'Demo' do
    use_frameworks!
    pod 'CocoaLumberjack', '>= 3.7.4'
    pod 'hpple', '>= 0.2.0'
end

post_install do |pi|
    pi.pods_project.targets.each do |t|
        t.build_configurations.each do |config|
            config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '14.0'
        end
        if t.respond_to?(:product_type) and t.product_type == "com.apple.product-type.bundle"
            t.build_configurations.each do |config|
                config.build_settings['CODE_SIGNING_ALLOWED'] = 'NO'
            end
        end
    end
end

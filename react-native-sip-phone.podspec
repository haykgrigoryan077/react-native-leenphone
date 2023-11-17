require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

reactVersion = JSON.parse(File.read(File.join(__dir__, "..", "react-native", "package.json")))["version"]

boost_compiler_flags = '-Wno-documentation'

rnVersion = reactVersion.split('.')[1]

react_native_node_modules_dir = File.join(File.dirname(`cd "#{Pod::Config.instance.installation_root.to_s}" && node --print "require.resolve('react-native/package.json')"`), '..')
pods_root = Pod::Config.instance.project_pods_root
react_native_common_dir_absolute = File.join(react_native_node_modules_dir, 'react-native', 'ReactCommon')
react_native_common_dir_relative = Pathname.new(react_native_common_dir_absolute).relative_path_from(pods_root).to_s

folly_flags = '-DFOLLY_NO_CONFIG -DFOLLY_MOBILE=1 -DFOLLY_USE_LIBCPP=1 -DRNVERSION=' + rnVersion

folly_compiler_flags = folly_flags + ' ' + '-Wno-comma -Wno-shorten-64-to-32'

Pod::Spec.new do |s|
  s.name         = "react-native-sip-phone"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]

  s.platforms    = { :ios => "9.0" }
  s.source       = { :git => "https://github.com/jc578271/react-native-sip-phone", :tag => "#{s.version}" }

  s.source_files = "ios/**/*.{h,m,mm,swift}"

  s.pod_target_xcconfig = {
    "USE_HEADERMAP" => "YES",
    "HEADER_SEARCH_PATHS" => "\"$(PODS_TARGET_SRCROOT)/ReactCommon\" \"$(PODS_TARGET_SRCROOT)\" \"$(PODS_ROOT)/RCT-Folly\" \"$(PODS_ROOT)/boost\" \"$(PODS_ROOT)/boost-for-react-native\" \"$(PODS_ROOT)/DoubleConversion\" \"$(PODS_ROOT)/Headers/Private/React-Core\"",
    "CLANG_CXX_LANGUAGE_STANDARD" => "c++17",
  }
  s.compiler_flags = folly_compiler_flags + ' ' + boost_compiler_flags + ' -DHERMES_ENABLE_DEBUGGER'
  s.xcconfig = {
    "GCC_PREPROCESSOR_DEFINITIONS" => "FOLLY_NO_CONFIG=1 FOLLY_HAVE_CLOCK_GETTIME=1",
    "HEADER_SEARCH_PATHS" => "\"$(PODS_ROOT)/boost\" \"$(PODS_ROOT)/boost-for-react-native\" \"$(PODS_ROOT)/glog\" \"$(PODS_ROOT)/RCT-Folly\" \"$(PODS_ROOT)/Headers/Public/React-hermes\" \"$(PODS_ROOT)/Headers/Public/hermes-engine\" \"$(PODS_ROOT)/#{react_native_common_dir_relative}\"",
    "OTHER_CFLAGS" => "$(inherited)" + " " + folly_flags
  }

  s.requires_arc = true

  s.dependency "React"
  s.dependency "React-Core"
  s.dependency "linphone-sdk"
end

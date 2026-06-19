Pod::Spec.new do |s|
  s.name             = 'native_argon2'
  s.version          = '0.0.1'
  s.summary          = 'Argon2 FFI plugin.'
  s.description      = 'Argon2 key derivation via Dart FFI.'
  s.homepage         = 'https://github.com/typedefai/native_argon2'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'typedefai' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'

  s.pod_target_xcconfig = {
    'HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/../src"'
  }

  s.ios.deployment_target = '12.0'
  s.osx.deployment_target = '10.13'
end

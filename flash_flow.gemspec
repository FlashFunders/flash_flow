# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'flash_flow/version'
Gem::Specification.new do |spec|
  spec.name          = "flash_flow"
  spec.version       = FlashFlow::VERSION
  spec.authors       = ["Flashfunders"]
  spec.email         = ["engineering@flashfunders.com"]
  spec.summary       = %q{Implementation of the flashfunders workflow}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'octokit'
  spec.add_dependency 'hipchat'

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "byebug"
  spec.add_development_dependency 'minitest-stub_any_instance'
end

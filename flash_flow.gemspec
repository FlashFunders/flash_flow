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
  spec.description   = %q{Flash flow is a command line tool for keeping your acceptance environment up to date}
  spec.homepage      = "https://github.com/FlashFunders/flash_flow"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'octokit', "~> 4.1"
  spec.add_dependency 'pivotal-tracker', "~> 0.5"
  spec.add_dependency 'ruby-graphviz', "> 0"
  spec.add_dependency 'percy-client'
  spec.add_dependency 'mail'
  spec.add_dependency 'prawn'
  spec.add_dependency 'google-api-client'

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake", "> 0"
  spec.add_development_dependency "minitest", "> 0"
  spec.add_development_dependency "byebug", "> 0"
  spec.add_development_dependency 'minitest-stub_any_instance', "> 0"
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'hal_interpretation/version'

Gem::Specification.new do |spec|
  spec.name          = "hal-interpretation"
  spec.version       = HalInterpretation::VERSION
  spec.authors       = ["Peter Williams"]
  spec.email         = ["pezra@barelyenough.org"]
  spec.summary       = %q{Build models from HAL documents.}
  spec.description   = %q{Declarative creation of ActiveModels from HAL documents.}
  spec.homepage      = "https://github.com/pezra/hal-interpretation"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "hal-client", ["~>2.2", ">2.2.0"]
  spec.add_dependency "hana"
  spec.add_dependency "multi_json"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~>3.0.0.beta"
  spec.add_development_dependency "rspec-collection_matchers"
  spec.add_development_dependency "activemodel"
  spec.add_development_dependency "activesupport"
end

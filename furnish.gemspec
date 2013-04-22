# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'furnish/version'

Gem::Specification.new do |gem|
  gem.name          = "furnish"
  gem.version       = Furnish::VERSION
  gem.authors       = ["Erik Hollensbe"]
  gem.email         = ["erik+github@hollensbe.org"]
  gem.description   = %q{A novel way to do virtual machine provisioning}
  gem.summary       = %q{A novel way to do virtual machine provisioning}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.required_ruby_version = '>= 1.9.3'

  gem.add_dependency 'palsy', '~> 0.0.4'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'minitest'
  gem.add_development_dependency 'guard-minitest'
  gem.add_development_dependency 'guard-rake', '~> 0.0.8'
  gem.add_development_dependency 'rdoc', '~> 4'
  gem.add_development_dependency 'rb-fsevent'
  gem.add_development_dependency 'simplecov'
end

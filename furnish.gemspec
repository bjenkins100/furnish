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

  gem.add_dependency 'palsy', '~> 0.0.1'

  gem.add_development_dependency 'rake'
  gem.add_development_dependency 'minitest', '~> 4.5.0'
end

$LOAD_PATH.push File.expand_path('../lib', __FILE__)
require 'grape-apidoc/version'

Gem::Specification.new do |s|
  s.name        = 'grape-apidoc'
  s.version     = GrapeApidoc::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Max Alekseev']
  s.email       = ['m.alexeev@millionagents.com']
  s.homepage    = 'https://github.com/pejack/grape-apidoc'
  s.summary     = 'Auto generate documentation for grape api'
  s.license     = 'MIT'

  s.add_runtime_dependency 'grape', '>= 0.8.0'
  s.add_runtime_dependency 'grape-entity'

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ['lib']
end

# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'xp5k/version'

Gem::Specification.new do |s|
  s.name        = 'xp5k'
  s.version     = XP5K::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Pascal Morillon', 'Matthieu Simonin']
  s.email       = ['pascal.morillon@irisa.fr', 'matthieu.simonin@inria.fr']
  s.homepage    = 'https://github.com/msimonin/xp5k'
  s.summary     = %q{A small Grid'5000 helper to submit jobs and deploy environments via REST API}
  s.description = %q{A small Grid'5000 helper to submit jobs and deploy environments via REST API}

  s.required_rubygems_version = '>= 1.3.6'

  s.add_dependency 'restfully', '~>0.6'
  s.add_dependency 'term-ansicolor', '>= 1.0.7'
  s.add_dependency 'json', '>= 1.5.1'

  s.add_development_dependency 'bundler', '>= 1.0.0'

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ['lib']

end

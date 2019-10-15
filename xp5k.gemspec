# -*- encoding: utf-8 -*-
$:.push File.expand_path('../lib', __FILE__)
require 'xp5k/version'

Gem::Specification.new do |s|
  s.name        = 'xp5k'
  s.version     = XP5K::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ['Pascal Morillon']
  s.email       = ['pascal.morillon@irisa.fr']
  s.license     = 'MIT'
  s.homepage    = 'https://github.com/pmorillon/xp5k'
  s.summary     = %q{A small Grid'5000 helper}
  s.description = %q{A small Grid'5000 helper to submit jobs and deploy environments via REST API}

  s.required_rubygems_version = '>= 1.3.6'

  s.add_dependency 'logger', '~> 1.4'
  s.add_dependency 'rest-client', '~> 2.1'
  #s.add_dependency 'restfully', '~>1.2.0'
  s.add_dependency 'term-ansicolor', '~> 1.3'
  s.add_dependency 'net-ssh-multi', '~> 1.2'
  s.add_dependency 'rake', '~> 13'

  s.add_development_dependency 'bundler', '~> 2.0'

  s.files         = `git ls-files`.split("\n")
  s.require_paths = ['lib']

end

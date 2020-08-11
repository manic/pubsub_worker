# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pubsub_worker/version'

Gem::Specification.new do |spec|
  spec.name          = 'pubsub_worker'
  spec.version       = PubsubWorker::Version::STRING
  spec.authors       = ['Keita Urashima', 'Manic Chuang']
  spec.email         = ['manic.chuang@gmail.com']

  spec.summary       = 'Google Cloud Pub/Sub worker to handle subscription'
  spec.homepage      = 'https://github.com/manic/pubsub_worker'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end

  spec.bindir        = 'exe'
  spec.executables   = ['pubsub_worker']
  spec.require_paths = ['lib']

  spec.required_ruby_version = '>= 2.6'

  spec.add_runtime_dependency 'activesupport'
  spec.add_runtime_dependency 'concurrent-ruby'
  spec.add_runtime_dependency 'google-cloud-pubsub', '>= 0.27.0'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec'
  spec.add_development_dependency 'rubocop'
end

Gem::Specification.new do |s|
  s.name = 'dynamini'
  s.version = '1.7.5'
  s.date = '2015-11-12'
  s.summary = 'DynamoDB interface'
  s.description = 'Lightweight DynamoDB interface gem designed as
                   a drop-in replacement for ActiveRecord.
                   Built & maintained by the team at yroo.com.'
  s.authors = ['Greg Ward', 'David McHoull', 'Alishan Ladhani', 'Emily Fan',
               'Justine Jones', 'Gillian Chesnais', 'Scott Chu', 'Jeff Li']
  s.email = 'dev@retailcommon.com'
  s.files = %w(lib/dynamini.rb lib/dynamini/base.rb
               lib/dynamini/configuration.rb lib/dynamini/test_client.rb)
  s.homepage = 'https://github.com/47colborne/dynamini'
  s.platform = Gem::Platform::RUBY
  s.license = 'MIT'

  s.add_dependency('activemodel', ['>= 3', '< 5.0'])
  s.add_dependency('aws-sdk', '~> 2')

  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'pry', '~> 0'
  s.add_development_dependency 'fuubar', '~> 2'
  s.add_development_dependency 'guard-rspec'
  s.add_development_dependency 'guard-shell'
end

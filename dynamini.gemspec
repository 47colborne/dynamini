Gem::Specification.new do |s|
  s.name = 'dynamini'
  s.version = '3.0.1'
  s.summary = 'DynamoDB interface'
  s.description = 'Lightweight DynamoDB interface gem designed as
                   a drop-in replacement for ActiveRecord.
                   Built & maintained by the team at yroo.com.'
  s.authors = ['Greg Ward', 'David McHoull', 'Alishan Ladhani', 'Emily Fan',
               'Justine Jones', 'Gillian Chesnais', 'Scott Chu', 'Jeff Li']
  s.email = 'dev@retailcommon.com'
  s.homepage = 'https://github.com/47colborne/dynamini'
  s.platform = Gem::Platform::RUBY
  s.license = 'MIT'

  s.files = `git ls-files -z`.split("\x0")
  s.executables = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ['lib']

  s.add_dependency('activemodel', '>= 3')
  s.add_dependency('aws-sdk-dynamodb', '~> 1')

  s.add_development_dependency 'rspec', '~> 3'
  s.add_development_dependency 'pry', '~> 0'
end

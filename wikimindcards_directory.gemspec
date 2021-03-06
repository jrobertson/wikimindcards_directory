Gem::Specification.new do |s|
  s.name = 'wikimindcards_directory'
  s.version = '0.4.0'
  s.summary = 'An experimental MindWords driven wiki editor which uses “cards”.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/wikimindcards_directory.rb']
  s.add_runtime_dependency('martile', '~> 1.5', '>=1.5.0')
  s.add_runtime_dependency('mindwords', '~> 0.8', '>=0.8.0')
  s.add_runtime_dependency('polyrex-links', '~> 0.5', '>=0.5.0')
  s.add_runtime_dependency('onedrb', '~> 0.1', '>=0.1.0')
  s.add_runtime_dependency('hashcache', '~> 0.2', '>=0.2.10')
  s.add_runtime_dependency('dxlite', '~> 0.6', '>=0.6.0')
  s.signing_key = '../privatekeys/wikimindcards_directory.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/wikimindcards_directory'
end

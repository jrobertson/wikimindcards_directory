Gem::Specification.new do |s|
  s.name = 'wikimindcards_directory'
  s.version = '0.1.0'
  s.summary = 'An experimental MindWords driven wiki editor which uses “cards”.'
  s.authors = ['James Robertson']
  s.files = Dir['lib/wikimindcards_directory.rb']
  s.add_runtime_dependency('martile', '~> 1.4', '>=1.4.6')
  s.add_runtime_dependency('mindwords', '~> 0.6', '>=0.6.3')
  s.add_runtime_dependency('polyrex-links', '~> 0.4', '>=0.4.3')
  s.signing_key = '../privatekeys/wikimindcards_directory.pem'
  s.cert_chain  = ['gem-public_cert.pem']
  s.license = 'MIT'
  s.email = 'digital.robertson@gmail.com'
  s.homepage = 'https://github.com/jrobertson/wikimindcards_directory'
end

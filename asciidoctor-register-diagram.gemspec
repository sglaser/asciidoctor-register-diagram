# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'asciidoctor-regregister-diagram/version'

$platform ||= RUBY_PLATFORM[/java/] || 'ruby'

Gem::Specification.new do |s|
  s.name          = "asciidoctor-regregister-diagram"
  s.version       = Asciidoctor::RegisterDiagram::VERSION
  s.authors       = ["Steve Glaser"]
  s.email         = ["sglaser@sglaser.com"]
  s.description   = %q{Asciidoctor hardware register diagramming extension}
  s.summary       = %q{An extension for asciidoctor that adds support for drawing hardware register diagrams using SVG}
  s.platform      = $platform
  s.homepage      = "https://github.com/sglaser/asciidoctor-regregister-diagram"
  s.license       = "MIT"

  begin
    s.files             = `git ls-files -z -- */* {CHANGELOG,LICENSE,README,Rakefile}*`.split "\0"
  rescue
    s.files             = Dir['**/*']
  end
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.3"
  s.add_development_dependency "rake"
  s.add_development_dependency "rspec"

  s.add_runtime_dependency "asciidoctor", "~> 1.5.0"
end

# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'version'

Gem::Specification.new do |s|
  s.name          = "asciidoctor-register-diagram"
  s.version       = Asciidoctor::RegisterDiagram::VERSION
  s.authors       = ["Steve Glaser"]
  s.email         = ["sglaser@nvidia.com"]
  s.description   = %q{Asciidoctor hardware register diagramming extension}
  s.summary       = %q{An extension for asciidoctor that adds support for drawing hardware register diagrams using SVG}
  s.homepage      = "https://github.com/sglaser/asciidoctor-register-diagram"
  s.license       = "MIT"

  begin
    s.files = `git ls-files -z -- */* {CHANGELOG,LICENSE,README,Rakefile}*`.split "\0"
  rescue
    s.files = Dir['**/*']
  end
  s.executables   = s.files.grep(%r{^bin/}) { |f| File.basename(f) }
  s.test_files    = s.files.grep(%r{^(test|spec|features)/})
  s.require_paths = ["lib"]

  s.add_development_dependency "bundler", "~> 1.7"
  s.add_development_dependency "rake", "~> 10.0"

  s.add_runtime_dependency "asciidoctor", "~> 1.5", ">= 1.5.0"
end

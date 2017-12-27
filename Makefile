all: html

both: clean html

clean:
	-rm register-diagram.html foo.html intel.html

html: register-diagram.html foo.html intel.html

register-diagram.html: register-diagram.adoc Makefile lib/asciidoctor-register-diagram.rb lib/preprocessor.rb lib/version.rb lib/asciidoc-register-diagram.css
	asciidoctor --trace -I ./lib -r asciidoctor-register-diagram.rb register-diagram.adoc

foo.html: foo.ref Makefile lib/asciidoctor-register-diagram.rb lib/preprocessor.rb lib/version.rb lib/asciidoc-register-diagram.css
	asciidoctor --trace -I ./lib -r asciidoctor-register-diagram.rb -r preprocessor.rb foo.ref <foo.ref

intel.html: intel.ref Makefile lib/asciidoctor-register-diagram.rb lib/preprocessor.rb lib/version.rb lib/asciidoc-register-diagram.css
	asciidoctor --trace -I ./lib -r asciidoctor-register-diagram.rb -r preprocessor.rb intel.ref <intel.ref

all: html

both: clean html

clean:
	-rm register-diagram.html

html: register-diagram.html

register-diagram.html: register-diagram.adoc Makefile lib/asciidoctor-register-diagram.rb
	asciidoctor --trace -I ./lib -r asciidoctor-register-diagram.rb register-diagram.adoc

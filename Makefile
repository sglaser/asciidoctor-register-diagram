all: html

both: clean html

clean:
#	-rm register-diagram.html foo.html intel.html dev_nvl_tb_trim.html
	-rm register-diagram.html foo.html intel.html

#html: register-diagram.html foo.html intel.html ref-file-instructions.html dev_nvl_tb_trim.html
html: register-diagram.html foo.html intel.html ref-file-instructions.html

register-diagram.html: register-diagram.adoc Makefile lib/asciidoctor-register-diagram.rb lib/asciidoctor-ref-diagram.rb lib/version.rb lib/asciidoc-register-diagram.css
	asciidoctor --trace -I ./lib -r asciidoctor-register-diagram.rb -d book register-diagram.adoc

foo.html: foo.ref Makefile lib/asciidoctor-register-diagram.rb lib/asciidoctor-ref-diagram.rb lib/version.rb lib/asciidoc-register-diagram.css
	asciidoctor --trace -I ./lib -r asciidoctor-register-diagram.rb -r asciidoctor-ref-diagram.rb -d book foo.ref

intel.html: intel.ref Makefile lib/asciidoctor-register-diagram.rb lib/asciidoctor-ref-diagram.rb lib/version.rb lib/asciidoc-register-diagram.css
	asciidoctor --trace -I ./lib -r asciidoctor-register-diagram.rb -r asciidoctor-ref-diagram.rb -d book intel.ref

ref-file-instructions.html: ref-file-instructions.adoc Makefile
	asciidoctor --trace ref-file-instructions.adoc

dev_nvl_tb_trim.html : dev_nvl_tb_trim.ref Makefile lib/asciidoctor-register-diagram.rb lib/asciidoctor-ref-diagram.rb
	asciidoctor --trace -I ./lib -r asciidoctor-register-diagram.rb -r asciidoctor-ref-diagram.rb -d book dev_nvl_tb_trim.ref

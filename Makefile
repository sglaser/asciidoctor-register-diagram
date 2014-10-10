#LIB=/usr/local/lib/ruby/gems/2.1.0/gems/asciidoctor-diagram-1.2.0/lib

.PHONY: all html clean snapshot

all: dev_timer.ref.html regpict.html
#all: regpict.html

html: dev_timer.ref.html regpict.html

dev_timer.ref.html: dev_timer.ref.adoc Makefile
	asciidoctor -d book -b html5 -r asciidoctor-diagram -o dev_timer.ref.html dev_timer.ref.adoc

clean:
	-rm -f dev_timer.ref.html

snapshot: dev_timer.ref.html Makefile dev_timer.ref.adoc README.adoc
	-rm -f snapshot/dev_timer.ref.html snapshot/dev_timer.ref.adoc snapshot/Makefile snapshot/README.adoc
	cp dev_timer.ref.html dev_timer.ref.adoc Makefile README.adoc snapshot
	chmod 444 snapshot/dev_timer.ref.html snapshot/dev_timer.ref.adoc snapshot/Makefile snapshot/README.adoc

regpict.html: regpict.adoc Makefile regpict_js.rb regpict.css
	asciidoctor -r /Users/sglaser/Repositories/literate-ref/regpict_js.rb regpict.adoc --trace

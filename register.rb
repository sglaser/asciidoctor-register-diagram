require 'asciidoctor'
require 'asciidoctor/extensions'

include ::Asciidoctor

# An extension that processes the contents of a block
# as a Slim template.
#
# Usage
#
#   [slim]
#   --
#   p Hello, World!
#   ul
#     li red
#     li green
#     li blue
#   --
#
class RegisterBlock < Extensions::BlockProcessor
  use_dsl

  named :register
  on_context :open
  parse_content_as :raw

  def process parent, reader, attrs
    document = parent.document
    lines = reader.lines

    unused = (document.attr 'unused', 'Reserved')

    tmpl = Slim::Template.new(format: html_syntax, pretty: pretty) { lines * EOL }
    html = tmpl.render document, (attributes_to_locals document.attributes)

    # QUESTION should we allow attribute references in the slim source?
    create_pass_block parent, html, attrs, subs: nil
  end

  def attributes_to_locals attrs
    attrs.inject({}) do |accum, (key,val)|
      accum[key.tr '-', '_'] = val
      accum
    end
  end
end

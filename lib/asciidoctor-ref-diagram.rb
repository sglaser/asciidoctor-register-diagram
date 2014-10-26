require 'asciidoctor-register-diagram'

module Asciidoctor
  module RefDiagram

    class RefItem
      attr_reader :name
      attr_reader :kind
      attr_reader :arg
      attr_reader :value
      attr_accessor :range
      attr_reader :named
      attr_reader :parent
      attr_reader :children
      attr_reader :attributes
      attr_reader :options

      def ref
        @ref + @kind
      end

      def short_ref
        @ref
      end

      REF_PLAIN    = -1
      REF_DEVICE   = 0
      REF_REGISTER = 1
      REF_FIELD    = 2
      REF_VALUE    = 3
      REF_MISC     = 4

      def level
        case
          when @kind.nil? || (@kind == '') then
            REF_PLAIN
          when @kind == 'D' then
            REF_DEVICE
          when (@kind == 'R') || (@kind == 'A') || (@kind == 'G') then
            REF_REGISTER
          when (@kind == 'F') then
            REF_FIELD
          when (@kind == 'V') || (@kind == 'T') then
            REF_VALUE
          else
            REF_MISC
        end
      end

      @@ref_hash = {}
      @@chunks   = []
      @@open     = [nil] * 5

      def initialize(name, first, last, kind, ref, arg, value, named, options)
        @name             = name
        @range            = first..last
        @kind             = kind
        @ref              = ref
        @arg              = arg
        @value            = value
        @named            = named
        @options          = options
        @children         = []
        @attributes       = []
        @@ref_hash[@name] = (@@ref_hash[@name] || []) << self
        @@chunks << self

        lvl = self.level
        if lvl >= 0
          @@open.each_index { |index| @@open[index] = nil if index > lvl }
          @@open[lvl] = self
          @parent     = (lvl > 0) ? @@open[level-1] : nil
          #RefItem::dump_open
          if lvl >= 0
            @parent.children << self if @parent != nil
          else
            @parent.attributes<< self if @parent != nil
          end
          #puts self.to_s, ''

          p = @parent
          until p.nil?
            if @name[0, p.name.length+1] == (p.name + '_')
              temp = @name[p.name.length + 1 .. -1]
              if @@ref_hash[temp]
                main = @@ref_hash[temp].find { |item| item.name == temp }
                @@ref_hash[temp] << self if main.nil?
              else
                @@ref_hash[temp] = [self]
              end
            end
            p = p.parent
          end
        end
      end

      WIDTH_MAP = {'1' => 8,
                   '2' => 16,
                   '4' => 32,
                   '8' => 64,
                   'F' => 128}

      def width
        WIDTH_MAP[@ref[-1]] || 0
      end

      def short_name
        case
          when @parent.nil? then
            @name
          when @name.length < @parent.name.length then
            @name
          when @name[0..@parent.name.length] != (@parent.name + '_') then
            @name
          else
            @name[(@parent.name.length + 1)..-1]
        end
      end

      def to_s(key = nil)
        n = ''
        n = " name=#{@name}" if key.nil? || key != @name
        p = ''
        p = " parent=#{@parent.name}" if @parent
        p = " NAMED #{p}" if @named
        "RefItem[level=#{level} kind=#{@kind} range=#{@range}#{n} arg=#{@arg} value=#{@value} ref=#{@ref} #{@children.length} children #{@attributes.length} attributes#{p}]" #" options=#{options}]"
      end

      class <<self
        def dump_refs
          @@ref_hash.each_pair do |key, item|
            item.each_index do |i|
              puts "    #{key}[#{i}]\n        => #{item[i].to_s(key)}\n"
            end
          end
        end

        def dump_open
          @@open.each_index { |index| puts "  @@open[#{index}] = #{@@open[index].name}" if @@open[index] }
        end

        def chunks
          @@chunks
        end

        def refs
          @@ref_hash
        end

        def lookup(name, context=nil)
          @@ref_hash[name]
        end

        def invent_empty_chunks(length)

        end
      end

    end

    class RealRefPreprocessor

      attr_reader :input
      attr_reader :lines
      attr_reader :options
      attr_reader :define_hash
      attr_reader :processed
      attr_reader :chunks
      attr_reader :document
      attr_reader :reader

      def define (key, value = '', ref = nil, arg = nil)
        val       = {:value => value}
        val[:arg] = arg if arg
        if ref
          m2 = /^[ \t]+(\/\*[ \t]*)?([-A-Z0-9][- A-Z0-9]*)([-A-Z0-9])([ \t]*\*\/)?[ \t]*$/.match(ref)
          if m2
            val[:ref]  = m2[2] + m2[3]
            val[:kind] = m2[3]
          end
        end
        @define_hash[key] = val
      end

      def undef(key)
        @define_hash.delete(key)
      end

      alias_method :delete, :undef

      def initialize document, reader
        @define_hash = {'ASCIIDOC' => {:val => 'ASCIIDOC'}}
        @options     = {'default_unused' => 'RsvdP',
                        'default_level'  => 0,
                        'default_width'  => 32}
        @processed   = false
        @lines       = []
        @input       = if reader.respond_to?(:index) && reader.respond_to?(:length)
                         input
                       elsif reader.respond_to?(:read_lines)
                         reader.read_lines
                       elsif reader.respond_to?(:readlines)
                         reader.readlines
                       else
                         []
                       end
        @document    = document
        @reader      = reader
      end

      def process
        return reader if @processed
        #puts '// begin RealRefPreprocessor.process'
        #puts "// @input[first 5]=#{@input[0..4]}"
        #puts "// @input[last 5] =#{@input[-5..-1]}"
        in_count       = 0
        mark           = -1
        named          = false
        stack          = [true]
        in_file_header = true
        ref_file       = ::File.extname(reader.file)== ".ref"
        #puts "reader.file = #{reader.file}, ::File.extname(reader.file) = #{::File.extname(reader.file)} ref_file = #{ref_file}"
        dump_asciidoc  = nil
        def_name       = def_arg = def_rest = def_val = def_ref = def_kind = nil
        # true accepting input
        # false rejecting input
        # nil rejecting input due to nested #ifdef/#ifndef
        while in_count < @input.length
          l          = input[in_count].chomp
          l_in_count = in_count
          while (in_count < @input.length) && (match = /\\[ \t]*$/.match(l))
            l[match.begin(0), match.end(0)] = @input[in_count].chomp # question: should we add a space before the next line?
            in_count                        += 1
          end
          skip = false
          #print "in=#{in_count} out=#{@lines.length} mark=#{mark} '#{l}'\n"

          if in_file_header
            #puts "// in_file_header #{in_count} ref_file=#{ref_file} \"#{l}\""
            if in_count >= 2
              ref_file      = true if /^:\s*ref_file\s*:\s*$/.match(l)
              ref_file      = false if /^:\s*ref_file\s*!\s*:\s*/.match(l)
              m             = /^:\s*dump_asciidoc\s*:\s*([^ \t]*)$/.match(l)
              dump_asciidoc = m[1] if m
              dump_asciidoc = nil if /^:\s*dump_asciidoc\s*!\s*:\s*/.match(l)
              if /^\s*$/.match(l) # ignore 1st 2 lines, then look for blank line
                in_file_header = false
                #@lines << ''
                #@lines << '[pass]'
                #@lines << '++++'
                #@lines << '   <link href="asciidoc-register-diagram.css" type="text/css" rel="stylesheet" />'
                #@lines << '++++'
                #@lines << ''
              end
            end
          elsif ref_file
            if /^#+[ \t]/.match(l)
              mark  = @lines.length
              named = true
            elsif /^=+[ \t]/.match(l)
              mark  = @lines.length
              named = true
            elsif /^\/\/[ \t]*asciidoc[ \t]+begin_chunk/.match(l)
              mark  = @lines.length
              named = false
            elsif /^\/\/[ \t]*asciidoc[ \t]+begin_named_chunk/.match(l)
              mark  = @lines.length
              named = true
            elsif m = /^\/\/[ \t]*asciidoc[ \t]+option[ \t]+(\w+)[ \t]*=[ \t]*(.*)/.match(l)
              @options = @options.dup[m[1]] = m[2] # important, clone @options to avoid affecting older chunks
              #puts "// asciidoc option #{m[1]}=#{m[2]}"
            elsif m = /^(\/\/[ \t]*asciidoc[ \t]+)?#define[ \t]+(\w+)[ \t]*(\([\w, ]*\))?[ \t]+(.*)$/.match(l)
              def_name = m[2]
              def_arg  = m[3]
              def_rest = m[4]
              if stack[-1]
                def_arg = def_arg.gsub(/[\(\)]/, '') if def_arg
                if def_rest && def_rest != '' # value and possibly ref
                  if m2 = /^(.*[^\s])?[ \t]+\/\*[ \t]*([-a-zA-Z0-9][- a-zA-Z0-9]*)([-a-zA-Z0-9])[ \t]*\*\/[ \t]*$/.match(def_rest) # value and ref both present
                    def_val  = m2[1]
                    def_ref  = m2[2]
                    def_kind = m2[3]
                    item     = RefItem.new(def_name, mark+1, @lines.length, def_kind, def_ref, def_arg, def_val, named, @options)
                  end
                else
                  value[:val] = def_rest # no ref present
                end
                mark  = @lines.length
                named = false
              end
              @define_hash[def_name] = item

            elsif m = /^(\/\/[ \t]*asciidoc[ \t]+)?#undef[ \t]+(\w+)[ \t]*$/.match(l)
              def_name = m[2]
              @define_hash.delete(def_name) if stack[-1]

            elsif m = /^(\/\/[ \t]*asciidoc[ \t]+)?#ifdef[ \t]+(\w+)[ \t]*$/.match(l)
              def_name = m[2]
              if stack[-1].nil?
                stack.push(nil)
              else
                stack.push(@define_hash.has_key?(def_name))
              end
              skip = true

            elsif m = /^(\/\/[ \t]*asciidoc[ \t]+)?#ifndef[ \t]+(\w+)[ \t]*$/.match(l)
              def_name = m[2]
              if stack[-1].nil?
                stack.push(nil)
              else
                stack.push(!@define_hash.has_key?(def_name))
              end
              skip = true

            elsif /^(\/\/[ \t]*asciidoc[ \t]+)?#else[ \t]*$/.match(l)
              if stack[-1] != nil
                stack[-1] = !stack[-1]
              end
              skip = true

            elsif /^(\/\/[ \t]*asciidoc[ \t]+)?#endif[ \t]*$/.match(l)
              stack.pop if stack.length > 1
              skip = true
            end
          end

          if stack[-1] && !skip
            @lines << l
          end
          in_count += 1
        end

        if ref_file
          bias = 0
          RefItem::chunks.each do |item|
            b = item.range.begin + bias
            e = item.range.end + bias
            if b != e
              reg = ['']
              if item.level == RefItem::REF_REGISTER
                found = false
                for i in b..e do
                  if /\[register.*\]$/.match(@lines[i])
                    found = true
                    break
                  end
                end
                if !found
                  reg << ''
                  reg << '[register]'
                  reg << '----'
                  reg << "width=#{item.width}"
                  for field in item.children
                    reg << "* [#{field.value}] #{field.short_name}"
                  end
                  reg << "----"
                  reg << ''
                end
              end
              reg.each do |reg_line|
                @lines.insert(e, reg_line)
                e    += 1
                bias += 1
              end
              if !item.named
                @lines.insert(b, '', "=%s %s" % ['=' * (@options['default_level'] + item.level), item.name], '', '')
                e    += 4
                bias += 4
              end
              @lines.insert(e, '[source,options="nowrap"]')
              e    += 1
              bias += 1
            end
            if /^#define[ \t]/.match(@lines[e])
              @lines[e].sub!(/^#define/, '    #define')
            end
            item.range = b..e
          end
        end

        if dump_asciidoc
          File.open(dump_asciidoc, mode='w') do |f|
            @lines.each_index { |i| f.puts "%-4d %s" % [i, @lines[i]] }
          end
        end


        @processed = true
        #puts '// end RealRefPreprocessor.process'
      end

    end

    class RefPreprocessor < Extensions::Preprocessor
      def process(document, reader)
        #puts '// begin RefPreprocessor.process'
        return reader if reader.eof?
        ref = RealRefPreprocessor.new(document, reader)
        ref.process
        reader.unshift_lines ref.lines
        #puts '// end RefPreprocessor.process'
      end
    end

    Extensions.register do
      preprocessor RefPreprocessor
    end
  end
end


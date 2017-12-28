require 'asciidoctor-register-diagram'

module Asciidoctor
  module RefDiagram

    class RefItemStore
      attr_reader :ref_hash
      attr_reader :chunks
      attr_reader :open

      def initialize
        @ref_hash = {}
        @chunks = []
        @open = [nil] * 5
      end

      def add_full_name(full_name, item)
        @ref_hash[full_name] = (@ref_hash[full_name] || []) << item
        @chunks << item
      end

      def add_short_name(short_name, item)
        if @ref_hash[short_name]
          temp = @ref_hash[short_name].find {|x| x.name == short_name}
          @ref_hash[short_name] << item if temp.nil?
        else
          @ref_hash[short_name] = [item]
        end
      end

      def set_level(lvl, item)
        @open.each_index {|i| @open[i] = nil if i > lvl}
        @open[lvl] = item
        (lvl > 0) ? @open[lvl - 1] : nil
      end

      def table_row(array)
        #'| ' + (array.map {|x| '"' + x.to_s.gsub(/\"/, '\"') + '"'}).join(' | ') + ' |'
        '| ' + array.join(' | ') + ' |'
      end

      def dump_refs
        puts 'begin from dump_refs'
        hdr = ['prefix', 'level', 'kind', 'range', 'name', 'arg', 'value', 'ref',
               'children', 'attributes', 'parent', 'named']
        retval = []
        retval.push('[options="header"]')
        retval.push('|===')
        retval.push(table_row(hdr))
        #retval.push(table_row([':---'] * hdr.length))
        count = 100
        @ref_hash.each_pair do |key, item|
          item.each_index do |i|
            if count == 0
              retval.push('|===')
              retval.push('')
              retval.push('')
              retval.push('[options="header"]')
              retval.push('|===')
              retval.push(table_row(hdr))
            end
            retval.push(table_row(["#{key}[#{i}]"] + item[i].to_tbl(key)))
            count = count == 0 ? 100 : count - 1
          end
        end
        retval.push('|===')
        retval.push('')
        retval.push('')
        puts 'return from dump_refs'
        retval
      end

      def dump_open
        @open.each_index {|index| puts "  @open[#{index}] = #{@open[index].name}" if @open[index]}
      end

      def lookup(name, context = nil)
        @ref_hash[name]
      end
    end

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
      attr_reader :store

      def ref
        short_ref + (@kind || ' ')
      end

      def short_ref
        @ref || '    '
      end

      REF_PLAIN = -1
      REF_DEVICE = 0
      REF_REGISTER = 1
      REF_FIELD = 2
      REF_VALUE = 3
      REF_MISC = 4

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

      def attr
        case @ref[0..1]
          when /R-/i
            'RO'
          when /C./i
            'RO Constant'
          when /RW/i
            'RW'
          when /-W/i
            'WO'
          else
            "Unknown '#{@ref[0..1]}'"
        end
      end

      def initialize(store, name, first, last, kind, ref, arg, value, named, options)
        @store = store
        @name = name
        @range = first..last
        @kind = kind
        @ref = ref
        @arg = arg
        @value = value
        @named = named
        @options = options
        @children = []
        @attributes = []

        @store.add_full_name(@name, self)

        lvl = self.level
        if lvl >= 0
          @parent = @store.set_level(lvl, self)
          #RefItem::dump_open if @debug
          if lvl >= 0
            @parent.children << self if @parent != nil
          else
            @parent.attributes << self if @parent != nil
          end
          #puts self.to_s, '' if @debug

          p = @parent
          until p.nil?
            if @name[0, p.name.length + 1] == (p.name + '_')
              temp = @name[p.name.length + 1..-1]
              @store.add_short_name(temp, self)
            end
            p = p.parent
          end
        end
      end


      def width
        case @ref[-1]
          when /^1/
            8
          when /^2/
            16
          when /^4/
            32
          when /^8/
            64
          when /^F/i
            128
          else
            0
        end
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
        "RefItem[level=#{level} kind=#{@kind} range=#{@range}#{n} arg=#{@arg} value=#{@value} ref=#{@ref} #{@children.length} children #{@attributes.length} attributes#{p}]"
      end

      def to_tbl(key = nil)
        n = (key.nil? || key != @name) ? @name : ''
        p = @parent ? @parent.name : ''
        d = @named ? @named : ''
        #"RefItem[level=#{level} kind=#{@kind} range=#{@range}#{n} arg=#{@arg} value=#{@value} ref=#{@ref} #{@children.length} children #{@attributes.length} attributes#{p}]"
        [level, kind, range, n, arg, value, ref, children.length, attributes.length, p, d]
      end

    end

    class RealRefPreprocessor

      attr_reader :input
      attr_reader :lines
      attr_reader :options
      attr_reader :define_hash
      attr_reader :processed
      attr_reader :store
      attr_reader :document
      attr_reader :reader
      attr_accessor :debug

      def define (key, value = '', ref = nil, arg = nil)
        val = {:value => value}
        val[:arg] = arg if arg
        if ref
          m2 = /^[ \t]+(\/\*[ \t]*)?([-A-Z0-9][- A-Z0-9]*)([-A-Z0-9])([ \t]*\*\/)?[ \t]*$/.match(ref)
          if m2
            val[:ref] = m2[2] + m2[3]
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
        @define_hash = {:ASCIIDOC => {:val => 'ASCIIDOC'}}
        @options = {:default_unused => 'RsvdP',
                    :default_level => 1,
                    :default_width => 32}
        @processed = false
        @lines = []
        @input = if reader.respond_to?(:index) && reader.respond_to?(:length)
                   input
                 elsif reader.respond_to?(:read_lines)
                   reader.read_lines
                 elsif reader.respond_to?(:readlines)
                   reader.readlines
                 else
                   []
                 end
        @document = document
        @reader = reader
        @debug = false
        @store = RefItemStore.new
        @insert_ref_list = false
      end

      def process
        return reader if @processed
        if @debug
          puts '// begin RealRefPreprocessor.process'
          puts "// @input[first 5]=#{@input[0..4]}"
          puts "// @input[last 5] =#{@input[-5..-1]}"
        end
        in_count = 0
        mark = -1
        named = false
        stack = [true]
        in_file_header = true
        ref_file = ::File.extname(reader.file)== ".ref"
        puts "reader.file = #{reader.file}, ::File.extname(reader.file) = #{::File.extname(reader.file)} ref_file = #{ref_file}" if @debug
        dump_asciidoc = nil
        def_name = def_arg = def_rest = def_val = def_ref = def_kind = nil
        # true accepting input
        # false rejecting input
        # nil rejecting input due to nested #ifdef/#ifndef
        while in_count < @input.length
          l = input[in_count].chomp
          l_in_count = in_count
          while (in_count < @input.length) && (match = /\\[ \t]*$/.match(l))
            l[match.begin(0), match.end(0)] = @input[in_count].chomp # question: should we add a space before the next line?
            in_count += 1
          end
          skip = false
          print "in=#{in_count} out=#{@lines.length} mark=#{mark} '#{l}'\n" if @debug

          if in_file_header
            puts "// in_file_header #{in_count} ref_file=#{ref_file} \"#{l}\"" if @debug
            if in_count >= 2
              @insert_ref_list = true if /^:\s*insert_ref_list\s*:\s*$/.match(l)
              @insert_ref_list = false if /^:\s*insert_ref_list\s*!\s*:\s*/.match(l)
              @debug = true if /^:\s*debug\s*:\s*$/.match(l)
              @debug = false if /^:\s*debug\s*!\s*:\s*/.match(l)
              ref_file = true if /^:\s*ref_file\s*:\s*$/.match(l)
              ref_file = false if /^:\s*ref_file\s*!\s*:\s*/.match(l)
              m = /^:\s*dump_asciidoc\s*:\s*([^ \t]*)$/.match(l)
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
              mark = @lines.length
              named = true
            elsif /^=+[ \t]/.match(l)
              mark = @lines.length
              named = true
            elsif /^\/\/[ \t]*asciidoc[ \t]+begin_chunk/.match(l)
              mark = @lines.length
              named = false
            elsif /^\/\/[ \t]*asciidoc[ \t]+begin_named_chunk/.match(l)
              mark = @lines.length
              named = true
            elsif (m = /^\/\/[ \t]*asciidoc[ \t]+option[ \t]+(\w+)[ \t]*=[ \t]*(.*)/.match(l))
              @options = @options.dup # clone @options to avoid affecting older chunks
              @options[m[1].to_sym] = m[2]
              puts "// asciidoc option #{m[1]}=#{m[2]}" if @debug
            elsif (m = /^(\/\/[ \t]*asciidoc[ \t]+)?#define[ \t]+(\w+)[ \t]*(\([\w, ]*\))?[ \t]+(.*)$/.match(l))
              def_name = m[2]
              def_arg = m[3]
              def_rest = m[4]
              if stack[-1]
                def_arg = def_arg.gsub(/[()]/, '') if def_arg
                if def_rest && def_rest != '' # value and possibly ref
                  if (m2 = /^(.*[^\s])?[ \t]+\/\*[ \t]*([-a-zA-Z0-9][- a-zA-Z0-9]*)([-a-zA-Z0-9])[ \t]*\*\/[ \t]*$/.match(def_rest)) # value and ref both present
                    def_val = m2[1]
                    def_ref = m2[2]
                    def_kind = m2[3]
                    item = RefItem.new(store, def_name, mark + 1, @lines.length, def_kind, def_ref, def_arg, def_val, named, @options)
                  end
                else
                  value[:val] = def_rest # no ref present
                end
                mark = @lines.length
                named = false
              end
              @define_hash[def_name] = item

            elsif (m = /^(\/\/[ \t]*asciidoc[ \t]+)?#undef[ \t]+(\w+)[ \t]*$/.match(l))
              def_name = m[2]
              @define_hash.delete(def_name) if stack[-1]

            elsif (m = /^(\/\/[ \t]*asciidoc[ \t]+)?#ifdef[ \t]+(\w+)[ \t]*$/.match(l))
              def_name = m[2]
              if stack[-1].nil?
                stack.push(nil)
              else
                stack.push(@define_hash.has_key?(def_name))
              end
              skip = true

            elsif (m = /^(\/\/[ \t]*asciidoc[ \t]+)?#ifndef[ \t]+(\w+)[ \t]*$/.match(l))
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
          @store.chunks.each do |item|
            #puts "chunks.each #{item.to_s}"
            b = item.range.begin + bias
            e = item.range.end + bias
            if b != e
              reg = ['']
              if item.level == RefItem::REF_REGISTER
                found = false
                for i in b..e do
                  if /\[register.*\]$/.match(@lines[i])
                    #puts "[register.*] matched #{@lines[i]}"
                    found = true
                    break
                  end
                end
                if !found
                  first = true
                  for i in 0..7
                    msb = 256 - i * 32
                    lsb = msb - 32
                    if item.width > lsb
                      reg << ''
                      if first
                        reg << "[[#{item.name}]]"
                        reg << ".#{item.name} Register"
                        first = false
                      end
                      reg << '[register]'
                      reg << '----'
                      reg << "width=#{item.width}"
                      reg << "visible_lsb=#{lsb}"
                      reg << "visible_msb=#{msb}"
                      reg << "show_attr=true"
                      for field in item.children
                        reg << "* [#{field.value}] #{field.short_name} [attr=\"#{field.attr}\"]"
                      end
                      reg << "----"
                      reg << ''
                    end
                  end
                end
              end
              reg.each do |reg_line|
                @lines.insert(e, reg_line)
                e += 1
                bias += 1
              end
              if !item.named
                @lines.insert(b, '', "=%s %s" % ['=' * (@options[:default_level] + item.level), item.name], '', '')
                e += 4
                bias += 4
              end
              @lines.insert(e, '[source,options="nowrap"]')
              e += 1
              bias += 1
            end
            if /^#define[ \t]/.match(@lines[e])
              @lines[e].sub!(/^#define/, '    #define')
            end
            item.range = b..e
          end
        end

        if @insert_ref_list
          @lines.push('')
          @lines.push('[[ref_list]]')
          @lines.push('.Ref List')
          @lines.push(@store.dump_refs.join("\n"))
          @lines.push('')
          puts "end insert_ref_list #{@lines.length} lines total"
        end

        if dump_asciidoc
          File.open(dump_asciidoc, mode = 'w') do |f|
            @lines.each_index {|i| f.puts "%s" % [@lines[i]]}
          end
        end

        @processed = true
        puts '// end RealRefPreprocessor.process' if @debug
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


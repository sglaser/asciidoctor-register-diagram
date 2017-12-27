class Preprocessor
  def initialize(input = nil, define_hash = {}, device_hash = {}, register_hash = {})
    @define_hash = define_hash
    @device_hash = device_hash
    @register_hash = register_hash
    @define_hash[:ASCIIDOC] = {:val => 'ASCIIDOC'}
    @define_hash[:register_unused] = {:val => 'RsvdP'} unless define_hash.has_key?(:register_unused)
    @define_hash[:register_level] = {:val => '2'} unless define_hash.has_key?(:register_level)
    @define_hash[:register_width] = {:val => '32'} unless define_hash.has_key?(:register_width)
    @src_map = {}
    @chunks = []
    @processed = false
    @input = if input.respond_to?(:index) && input.respond_to?(:length)
               input
             elsif input.respond_to?(:readlines)
               input.readlines
             else
               []
             end
    @lines = []
  end

  attr_reader :src_map
  attr_reader :input
  attr_reader :lines
  attr_reader :define_hash
  attr_reader :device_hash
  attr_reader :register_hash
  attr_reader :processed
  attr_reader :chunks

  def define (key, value = '', ref = nil, arg = nil)
    val = {:value => value}
    val[:arg] = arg if arg
    if ref
      m2 = /^[ \t]+(\/\*[ \t]*)?([-A-Z0-9][- A-Z0-9]*)([-A-Z0-9])([ \t]*\*\/)?[ \t]*$/.match(ref)
      if m2
        val[:ref] = m2[2] + m2[3]
        val[:kind] = m2[3]
        @device_hash[key] = val if m2[3] == 'D'
        @register_hash[key] = val if m2[3] == 'R' || m2[3] == 'A'
      end
    end
    @define_hash[key] = val
  end

  def undef(key)
    @define_hash.delete(key)
    @device_hash.delete(key)
  end

  alias_method :delete, :undef

  # Return the next complete input line.
  # If a line matches @continue regular expression, replace the matched text with the next input line
  # @return [String]
  def process
    return if @processed

    in_count = 0
    mark = -1
    start_of_chunk = -1
    last_of_chunk = -1
    chunk_name = ''
    chunk_loc = -1
    chunk_level = @define_hash[:register_level][:val]
    chunk_unused = @define_hash[:register_unused][:val]
    chunk_width = @define_hash[:register_width][:val]
    stack = [true]
    def_name = def_arg = def_rest = def_val = def_ref = def_kind = nil
    # true accepting input
    # false rejecting input
    # nil rejecting input due to nested #ifdef/#ifndef
    while in_count < @input.length
      l = input[in_count].chomp
      l_in_count = in_count
      while (in_count < @input.length) && (match = /\\[ \t]*/.match(l))
        l[match.begin(0), match.end(0)] = @input[in_count].chomp # question: should we add a space before the next line?
        in_count += 1
      end
      skip = false
      #print "in=#{in_count} out=#{@lines.length} mark=#{mark} start=#{start_of_chunk} '#{l}'\n"

      if /^#+[ \t]/.match(l)
        mark = @lines.length
      elsif /^=+[ \t]/.match(l)
        mark = @lines.length
      elsif (m = /^#define[ \t]+(\w+)[ \t]*(\([\w, ]*\))?[ \t]+(.*)$/.match(l))
        def_name = m[1]
        def_arg = m[2]
        def_rest = m[3]
        if stack[-1]
          value = {}
          value[:arg] = def_arg.gsub(/[\(\)]/, '') if def_arg
          if def_rest && def_rest != '' # value and possibly ref
            if (m2 = /^(.*)[ \t]+\/\*[ \t]*([-A-Z0-9][- A-Z0-9]*)([-A-Z0-9])[ \t]*\*\/[ \t]*$/.match(def_rest)) # value and ref both present
              def_val = m2[1]
              def_ref = m2[2]
              def_kind = m2[3]
              value[:val] = def_val
              value[:ref] = def_ref + def_kind
              value[:kind] = def_kind
              @device_hash[def_name] = value if value[:kind] == 'D'
              @register_hash[def_name] = value if (value[:kind] == 'R' || value[:kind] == 'A')
              if /^[DRA]$/.match(value[:kind])
                if start_of_chunk >= 0 && last_of_chunk >= 0
                  @chunks << {:start => start_of_chunk,
                              :end => last_of_chunk,
                              :key => chunk_loc,
                              :name => chunk_name,
                              :unused => chunk_unused,
                              :level => chunk_level,
                              :width => chunk_width}
                  print "chunk=#{@chunks[-1]}\n"
                end
                start_of_chunk = mark + 1
                chunk_name = def_name
                chunk_loc = @lines.length
                chunk_unused = @define_hash[:register_unused][:val]
                chunk_level = @define_hash[:register_level][:val]
                chunk_width = @define_hash[:register_width][:val]
              end
              last_of_chunk = @lines.length
            else
              value[:val] = def_rest # no ref present
            end
          end
          @define_hash[def_name] = value
          mark = @lines.length
        end

      elsif (m = /^#undef[ \t]+(\w+)[ \t]*$/.match(l))
        def_name = m[1]
        @define_hash.delete(def_name) if stack[-1]

      elsif (m = /^#ifdef[ \t]+(\w+)[ \t]*$/.match(l))
        def_name = m[1]
        if stack[-1].nil?
          stack.push(nil)
        else
          stack.push(@define_hash.has_key?(def_name))
        end
        skip = true

      elsif (m = /^#ifndef[ \t]+(\w+)[ \t]*$/.match(l))
        def_name = m[1]
        if stack[-1].nil?
          stack.push(nil)
        else
          stack.push(!@define_hash.has_key?(def_name))
        end
        skip = true

      elsif /^#else[ \t]*$/.match(l)
        if stack[-1] != nil
          stack[-1] = !stack[-1]
        end
        skip = true

      elsif /^#endif[ \t]*$/.match(l)
        stack.pop if stack.length > 1
        skip = true
      end

      if stack[-1] && !skip
        @src_map[@lines.length] = l_in_count
        @lines << l
      end
      in_count += 1
    end

    if start_of_chunk > 0
      @chunks << {:start => start_of_chunk,
                  :end => last_of_chunk,
                  :key => chunk_loc,
                  :name => chunk_name,
                  :unused => chunk_unused,
                  :level => chunk_level,
                  :width => chunk_width}
    end
    @processed = true

  end
end

if true
  pre = Preprocessor.new($stdin, {:foo => {:val => 'foo_value'}})

#print "\n\nBefore:\n"
#print "pre.processed ", pre.processed, "\n"
#print "pre.input:\n"
#pre.input.each_index { |index| print "-- #{index}: #{pre.input[index]}" }
#print "pre.define_hash ", pre.define_hash, "\n"
#print "pre.src_map ", pre.src_map, "\n"
#print "pre.lines:\n"
#pre.lines.each_index { |index| print "++ #{index}: #{pre.lines[index]}\n" }

  print "\n\n"
  pre.process
  print "\n\n"

#print "\n\nAfter:\n"
#print 'pre.processed ', pre.processed, "\n"
#pre.input.each_index { |index| print "pre.input[#{index}]:\t#{pre.input[index]}" }
  print 'pre.define_hash {'
  pre.define_hash.each_pair {|key, value| print "\n   #{key}\t=> #{value}"}
  print "\n}\n"
  print 'pre.device_hash {'
  pre.device_hash.each_pair {|key, value| print "\n   #{key}\t=> #{value}"}
  print "\n}\n"
  print 'pre.register_hash {'
  pre.register_hash.each_pair {|key, value| print "\n   #{key}\t=> #{value}"}
  print "\n}\n"
#print 'pre.src_map ', pre.src_map, "\n"
  print 'pre.chunks {'
  pre.chunks.each {|value| print "\n   #{value}"}
  print "\n}\n"
#pre.lines.each_index { |index| print "pre.lines[#{index}]:\t#{pre.lines[index]}\n" }
#pre.lines.each_index { |index| print "pre.input[#{index} => #{pre.src_map[index]}]: #{pre.input[pre.src_map[index]]}" }

  pre.chunks.each do |chunk|
    print "\n#{chunk}\n"
    (chunk[:start]..chunk[:end]).each {|index| print "  #{index}:\t#{pre.lines[index]}\n"}
  end

  print "\n\n"

end
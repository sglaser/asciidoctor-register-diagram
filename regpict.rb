RUBY_ENGINE = 'unknown' unless defined? RUBY_ENGINE
RUBY_ENGINE_OPAL = (RUBY_ENGINE == 'opal')
RUBY_ENGINE_JRUBY = (RUBY_ENGINE == 'jruby')

module Regpict
  RUBY_ENGINE = ::RUBY_ENGINE
  NULL = "\0"
  CG_BLANK = '[ \\t]'
  # Matches a space escaped by a backslash.
  #
  # Examples
  #
  #   one\ two\ three
  #
  ESCAPED_SPACE_RX = /\\(#{CG_BLANK})/

  # Matches a space delimiter that's not escaped.
  #
  # Examples
  #
  #   one two	three	four
  #
  SPACE_DELIMITER_RX = /([^\\])#{CG_BLANK}+/


  def load input, options = {}
    options = options.dup

    timings = options[:timings]
    timings.start :read if timings

    attributes = options[:attributes] =
        if !(attrs = options[:attributes])
          {}
        elsif attrs.is_a? ::Hash
          attrs.dup
        elsif attrs.is_a? ::Array
          attrs.inject({}) do |accum, entry|
            k, v = entry.split '=', 2
            accum[k] = v || ''
            accum
          end
        elsif attrs.is_a? ::String
          capture_1 = ::RUBY_ENGINE_OPAL ? '$1' : '\1'
          attrs = attrs.gsub(SPACE_DELIMITER_RX, %(#{capture_1}#{NULL})).gsub(ESCAPED_SPACE_RX, capture_1)
          attrs.split(NULL).inject({}) do |accum, entry|
            k, v = entry.split '=', 2
            accum[k] = v || ''
            accum
          end
        elsif (attrs.respond_to? :keys) && (attrs.respond_to? :[])
          original_attrs = attrs
          attrs = {}
          original_attrs.keys.each do |key|
            attrs[key] = original_attrs[key]
          end
          attrs
        end

    if input.is_a? ::File
      lines = input.readlines
      input_mtime = input.mtime
      input = ::File.new ::File.expand_path input.path
      input_path = input.path
      # hold off on setting infile and indir until we get a better sense of their purpose
      attributes['docfile'] = input_path
      attributes['docdir'] = ::File.dirname input_path
      attributes['docname'] = ::File.basename input_path, (::File.extname input_path)
      attributes['docdate'] = docdate = input_mtime.strftime('%Y-%m-%d')
      attributes['doctime'] = doctime = input_mtime.strftime('%H:%M:%S %Z')
      attributes['docdatetime'] = %(#{docdate} #{doctime})
    elsif input.respond_to? :readlines
      # NOTE tty, pipes & sockets can't be rewound, but can't be sniffed easily either
      # just fail the rewind operation silently to handle all cases
      begin
        input.rewind
      rescue
        nil
      end
      lines = input.readlines
    elsif input.is_a? ::String
      lines = input.lines.entries
    elsif input.is_a? ::Array
      lines = input.dup
    else
      raise ::ArgumentError, %(Unsupported input type: #{input.class})
    end

    if timings
      timings.record :read
      timings.start :parse
    end
    doc = (Document.new lines, options).parse
    timings.record :parse if timings
    doc
  end

  class Document
    REGOPTS_DEFULT_BOOLEANS = {
        :all_inside => false
    }
    REGOPTS_DEFAULT_NUMBERS = {
        :width => 32,
        :cell_width => 16,
        :cell_height => 32,
        :cell_internal_height => 8,
        :cell_value_top => 16,
        :cell_bit_value_top => 20,
        :cell_name_top => 16,
        :bracket_height => 4,
        :cell_top => 40,
        :bit_width_pos => 20,
        :max_fig_width => 720,
        :fig_left => 32,
        :visible_lsb => 0,
        :visible_msb => 65536
    }
    REGOPTS_DEFAULT_STRINGS = {
        :default_unused => 'RsvdP',
        :default_attr => 'other',
        :fig_name => '???'
    }
    REGOPTS_DEFAULTS = REGOPTS_DEFAULT_NUMBERS.merge(REGOPTS_DEFAULT_STRINGS).merge(REGOPTS_DEFULT_BOOLEANS)

    def create_attrs
      return if self.class.public_method.defined? :width
      code = ''
      REGOPT_DEFAULT_NUMBERS.each do |k, v|
        code << "def #{k}; @regopts[:#{k}] end\n"
        code << "def #{k}=(value); @regopts[:#{k}] = value.to_i; end\n"
      end
      REGOPT_DEFAULT_STRINGS.each do |k, v|
        code << "def #{k}; @regopts[:#{k}] end\n"
        code << "def #{k}=(value); @regopts[:#{k}] = value.to_s; end\n"
      end
      REGOPTS_DEFULT_BOOLEANS.each do |k, v|
        code << "def #{k}; @regopts[:#{k}] end\n"
        code << "def #{k}=(valud); @regopts[:#{k}] = if value then treu else false; end\m"
      end
    end

    foo = if bar then true else false

    puts "create_attrs: class_eval #{code}\n"
    class_eval code
  end

  def initialize data = nil, options = {}
    # copy attributes map and normalize keys
    # attribute overrides are attributes that can only be set from the commandline
    # a direct assignment effectively makes the attribute a constant
    # a nil value or name with leading or trailing ! will result in the attribute being unassigned
    @regopts = REGOPTS_DEFAULTS.dup
    options.each do |key, value|
      if key.start_with? '!'
        key = key[1..-1]
        value = nil
      elsif key.end_with? '!'
        key = key.chop
        value = nil
      end
      @regopts[key.downcase] = value
    end
    @parsed = false
    if options[:base_dir]
      @base_dir = @regopts['docdir'] = ::File.expand_path(options[:base_dir])
    else
      if @regopts['docdir']
        @base_dir = @regopts['docdir'] = ::File.expand_path(@regopts['docdir'])
      else
        @base_dir = @regopts['docdir'] = ::File.expand_path(::Dir.pwd)
      end
    end
  end

  def parse
    return if @parsed
    lines.each do |line|
      # ignore full line comment: line starting with // or #
      next if line.match(/^\s*(\/\/|#)/)
      # ingore blank lines
      next if line.match(/^\s*$/)
      # comment: // non-escaped to end of line
      # comment: # non-escaped to end of line
      line.sub(/([^\\])\/\/.*$/, '\1')
      line.sub(/([^\\])#.*$/, '\1')
      if opt = line.match(/^(\w+)\s*=\s*(["'])(.*)\2(.*)$/)
        if REGOPTS_DEFAULTS.has_key? opt[0]
        end
      end
    end
  end
end
end

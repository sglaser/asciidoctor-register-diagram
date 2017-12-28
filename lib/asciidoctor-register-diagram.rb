module Asciidoctor
  module RegisterDiagram
    class RegisterField
      attr_accessor :lsb
      attr_accessor :msb
      attr_accessor :is_unused
      attr_accessor :attr
      attr_accessor :name
      attr_accessor :orig_name
      attr_accessor :value
      attr_accessor :register
      attr_accessor :key
      attr_accessor :add_class
      attr_accessor :show_attr

      def try_default(raw, tag, default)
        tag_str = tag.to_s
        raw.has_key?(tag) ? raw[tag] : raw.has_key?(tag_str) ? raw[tag_str] : default
      end

      def initialize(reg, raw = {}, key = nil)
        @register = reg

        @lsb = try_default(raw, :lsb, nil)
        @msb = try_default(raw, :msb, nil)

        if (@lsb.nil? || @lsb == '') && (@msb != '')
          @lsb = @msb
        end

        if (@msb.nil? || @msb == '') && (@lsb != '')
          @msb = @lsb
        end

        @is_unused = try_default(raw, :is_unused, false)
        @show_attr = try_default(raw, :show_attr, reg.show_attr)
        @attr = try_default(raw, :attr, @is_unused ? reg.default_unused : reg.default_attr)
        @value = try_default(raw, :value, nil)
        @add_class = try_default(raw, :add_class, '')
        if key.nil? || key == ''
          @key = (@is_unused ? 'unused' : 'field') + " [#{@msb}:#{@lsb}]"
        else
          @key = key
        end
        @name = try_default(raw, :name, @key)
        @orig_name = try_default(raw, :orig_name, @key)
      end

      def to_s
        v = @value ? " value=#{@value}" : ''
        u = @is_unused ? ' UNUSED' : ''
        b = @lsb == @msb ? "   [%2d]" % [@lsb] : "[%2d:%2d]" % [@msb, @lsb]
        k = @key && @key != @name ? " key=#{@key}" : ''
        a = @add_class != '' ? " add_class=#{@add_class}" : ''
        w = (@register.name_max_width > 0) ? @register.name_max_width : @name.length
        "#{b} %-#{w}s #{k} %-6s#{u}#{a}#{v}" % [@name, @attr]
      end

    end

    class HtmlElement
      attr_accessor :tag
      attr_accessor :content
      attr_accessor :attr

      def initialize(tag, attr = {}, content = [])
        @tag = tag
        @content = content
        @attr = attr
      end

      def append(*items)
        @content += items
      end

      def prepend(*items)
        @content = items + @content
      end

      def set(attr, value)
        @attr[attr] = value
      end

      def append_element(tag, attr = {}, content = [])
        self.append(HtmlElement.new(tag, attr, content))
      end

      def delete(attr)
        @attr.delete(attr)
      end

      def add_class(c)
        if @attr.has_key?(:class)
          old = @attr[:class].split(/\s+/)
          new = c.split(/\s+/)
          @attr[:class].replace((old + new).sort.uniq.join(' '))
        else
          @attr[:class] = c
        end
      end

      def delete_class(c)
        if @attr.has_key?(:class)
          old = @attr[:class].split(/\s+/)
          new = c.split(/\s+/)
          @attr[:class].replace((old - new).sort.uniq.join(' '))
        end
      end

      def to_s(level = 0)
        temp = ''
        @attr.keys.sort.each do |key|
          temp += " #{key}=\"#{@attr[key]}\""
        end
        prefix = (@content.length <= 1) ? '' : (' ' * level)
        prefix2 = (@content.length <= 1) ? '' : (' ' * (level + 2))
        postfix = (@content.length <= 1) ? '' : (level > 0 ? "\n  " : "\n")
        temp = ["#{prefix}<#{@tag}#{temp}>#{postfix}"]
        temp += @content.map {
            |item| prefix2 + (item.is_a?(HtmlElement) ? item.to_s(level + 2) : item.to_s) + postfix
        }
        temp += ["#{prefix}</#{@tag}>#{postfix}"]
        temp = temp.join('')
        (level == 0) ? "#{temp}\n\n" : temp
      end

      alias_method :dump, :to_s
    end

    class PathElement < HtmlElement
      def initialize(attr = {})
        super('path', attr)
        @attr[:d] = '' unless @attr.has_key?(:d)
      end

      def move_to_abs(x, y)
        @attr[:d] += 'M%3.1f %3.1f ' % [x, y]
      end

      def line_to_abs(x, y)
        @attr[:d] += 'L%3.1f %3.1f ' % [x, y]
      end

      def move_to_rel(x, y)
        @attr[:d] += 'm%3.1f %3.1f ' % [x, y]
      end

      def line_to_rel(x, y)
        @attr[:d] += 'l%3.1f %3.1f ' % [x, y]
      end

      def line_to_horiz_abs(x)
        @attr[:d] += 'H%3.1f ' % [x]
      end

      def line_to_vert_abs(y)
        @attr[:d] += 'V%3.1f ' % [y]
      end

      def line_to_horiz_rel(x)
        @attr[:d] += 'h%3.1f ' % [x]
      end

      def line_to_vert_rel(y)
        @attr[:d] += 'v%3.1f ' % [y]
      end

      def close_path
        @attr[:d] += 'Z'
      end

      def curve_to_cubic_abs(x, y, x1, y1, x2, y2)
        @attr[:d] += 'C%3.1f %3.1f %3.1f %3.1f %3.1f %3.1f ' % [x1, y1, x2, y2, x, y]
      end

      def curve_to_cubic_rel(x, y, x1, y1, x2, y2)
        @attr[:d] += 'c%3.1f %3.1f %3.1f %3.1f %3.1f %3.1f ' % [x1, y1, x2, y2, x, y]
      end

      def curve_to_cubic_smooth_abs(x, y, x2, y2)
        @attr[:d] += 'S%3.1f %3.1f %3.1f %3.1f ' % [x2, y2, x, y]
      end

      def curve_to_cubic_smooth_rel(x, y, x2, y2)
        @attr[:d] += 's%3.1f %3.1f %3.1f %3.1f ' % [x2, y2, x, y]
      end

      def curve_to_quadratic_abs(x, y, x1, y1)
        @attr[:d] += 'Q%3.1f %3.1f %3.1f %3.1f ' % [x1, y1, x, y]
      end

      def curve_to_quadratic_rel(x, y, x1, y1)
        @attr[:d] += 'q%3.1f %3.1f %3.1f %3.1f ' % [x1, y1, x, y]
      end

      def curve_to_quadratic_smooth_abs(x, y)
        @attr[:d] += 'T%3.1f %3.1f ' % [x, y]
      end

      def curve_to_quadratic_smooth_rel(x, y)
        @attr[:d] += 't%3.1f %3.1f ' % [x, y]
      end

      def arc_abs(x, y, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag)
        @attr[:d] += 'A%3.1f %3.1f %3.1f %3.1f %3.1f %p %p ' % [rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x, y]
      end

      def arc_rel(x, y, rx, ry, x_axis_rotation, large_arc_flag, sweep_flag)
        @attr[:d] += 'a%3.1f %3.1f %3.1f %3.1f %3.1f %p %p ' % [rx, ry, x_axis_rotation, large_arc_flag, sweep_flag, x, y]
      end

      def fill
        @attr.has_key?(:fill) ? @attr[:fill] : ''
      end

      def fill=(str)
        @attr[:fill] = str
      end
    end

    class RegisterDiagram

      attr_reader :width
      attr_reader :show_attr
      attr_reader :default_unused
      attr_reader :default_attr
      attr_reader :cell_width
      attr_reader :cell_height
      attr_reader :cell_internal_height
      attr_reader :cell_value_top
      attr_reader :cell_bit_value_top
      attr_reader :cell_name_top
      attr_reader :bracket_height
      attr_reader :cell_top
      attr_reader :bit_width_pos
      attr_reader :max_fig_width
      attr_reader :fig_left
      attr_reader :visible_lsb
      attr_reader :visible_msb
      attr_reader :field_hash
      attr_reader :field_array
      attr_reader :name_max_width
      attr_reader :text_height
      attr_reader :svg
      attr_reader :reg
      attr_reader :debug

      # x position of left edge of bit i
      def left_of(i)
        if i >= @visible_msb
          @fig_left
        elsif i >= @visible_lsb
          @fig_left + @cell_width * (@visible_msb - i - 1)
        elsif i >= 0
          @fig_left + @cell_width * (@visible_msb - @visible_lsb - 1)
        else
          @fig_left + @cell_width * (@visible_msb - @visible_lsb - i)
        end
      end

      # x position of right edge of bit i
      def right_of(i)
        if i >= @visible_msb
          @fig_left
        elsif i >= @visible_lsb
          @fig_left + @cell_width * (@visible_msb - i)
        elsif i >= 0
          @fig_left + @cell_width * (@visible_msb - @visible_lsb)
        else
          @fig_left + @cell_width * (@visible_msb - @visible_lsb - i + 1)
        end
      end

      # x position of middle of bit i
      def middle_of(i)
        if i >= @visible_msb
          @fig_left
        elsif i >= @visible_lsb
          @fig_left + @cell_width * (@visible_msb - i - 0.5)
        elsif i >= 0
          @fig_left + @cell_width * (@visible_msb - @visible_lsb - 0.5)
        else
          @fig_left + @cell_width * (@visible_msb - @visible_lsb - i - 0.5)
        end
      end

      def set_default_number(prop, defval)
        prop_str = prop.to_s
        (@reg.has_key?(prop) ? @reg[prop] : @reg.has_key?(prop_str) ? @reg[prop_str] : defval).to_i
      end

      def set_default_string(prop, defval)
        prop_str = prop.to_s
        (@reg.has_key?(prop) ? @reg[prop] : @reg.has_key?(prop_str) ? @reg[prop_str] : defval).to_s
      end

      def set_default_boolean(prop, defval)
        prop_str = prop.to_s
        value = (@reg.has_key?(prop) ? @reg[prop] : @reg.has_key?(prop_str) ? @reg[prop_str] : defval).to_s.downcase
        value != nil && value != "false" && value != false
      end

      def set_default(prop, defval)
        prop_str = prop.to_s
        (@reg.has_key?(prop) ? @reg[prop] : @reg.has_key?(prop_str) ? @reg[prop_str] : defval)
      end

      def initialize(reg)
        @reg = reg

        @width = set_default_number(:width, 32)
        @show_attr = set_default_boolean(:show_attr, false)
        @default_unused = set_default_string(:default_unused, 'RsvdP')
        @default_attr = set_default_string(:default_attr, 'other')
        @cell_width = set_default_number(:cell_width, 16)
        @cell_height = set_default_number(:cell_height, 32)
        @cell_internal_height = set_default_number(:cell_internal_height, 8)
        @cell_value_top = set_default_number(:cell_value_top, 16) # top of text for regFieldValueInternal
        @cell_bit_value_top = set_default_number(:cell_bit_value_top, 20) # top of text for regFieldBitValue
        @cell_name_top = set_default_number(:cell_name_top, 16) # top of text for regFieldNameInternal
        @bracket_height = set_default_number(:bracket_height, 6)
        @cell_top = set_default_number(:cell_top, 40)
        @bit_width_pos = set_default_number(:bit_width_pos, 20)
        @max_fig_width = set_default_number(:max_fig_width, 1000) # 7.5 inches (assuming 96 px per inch
        @fig_left = set_default_number(:fig_left, 32).to_f
        @visible_lsb = set_default_number(:visible_lsb, 0)
        @visible_msb = set_default_number(:visible_msb, @width)
        @text_height = set_default_number(:text_height, 18)
        @debug = set_default_boolean(:debug, false)

        if @visible_msb < 0
          @visible_msb = 0
        end
        if @visible_msb > @width
          @visible_msb = @width
        end
        if @visible_lsb < 0
          @visible_lsb = 0
        end
        if @visible_lsb > @width
          @visible_lsb = @width
        end

        @name_max_width = 0
        @field_hash = {}
        @field_array = [] * (@width + 1)
        set_default(:fields, {}).each_pair do |key, item|
          f = RegisterField.new(self, item, key)
          for i in f.lsb..f.msb
            @field_array[i] = f
          end
          @field_hash[key] = f
          @name_max_width = f.name.length if f.name.length > @name_max_width
        end

      end

      def new_unused_field(msb, lsb)
        RegisterField.new(self, {:msb => msb,
                                 :lsb => lsb,
                                 :show_attr => @show_attr,
                                 :name => @default_unused,
                                 :is_unused => true})
      end

      def invent_unused
        lsb = -1 # if non-nil, contains bit# of lsb of a string of unused bits
        for i in 0..@width
          if @field_array[i] && lsb >= 0 # first 'used' bit after stretch of unused bits, invent an 'unused' field
            f = new_unused_field(i - 1, lsb)
            for j in lsb..(i - 1)
              @field_array[j] = f
            end
            lsb = -1
          end
          if lsb < 0 && !@field_array[i] # starting a string of unused bits
            lsb = i
          end
        end
        if lsb >= 0
          f = new_unused_field(@width - 1, lsb)
          for j in lsb..(@width - 1)
            @field_array[j] = f
          end
        end
      end

      def dump
        print "\nRegister: width=#{@width} default_unused='#{@default_unused}'",
              " cell_width=#{@cell_width} cell_height=#{@cell_height} cell_internal_height=#{@cell_internal_height}",
              " cell_top=#{@cell_top} bracket_height=#{@bracket_height} name_max_width=#{@name_max_width}\n\n"
        @field_hash.each_pair do |key, item|
          print " hash:  %-#{@name_max_width}s => %s\n" % [key, item]
        end
        print "\n"
        @field_array.each_index do |index|
          print " array: %#{@name_max_width}d => #{@field_array[index]}\n" % [index]
        end
        print "\n"
      end


      def process
        #dump if @debug

        next_bit_line = @cell_top + @cell_height + 20 # 76
        bit_line_count = 0
        max_text_width = 0

        @svg = HtmlElement.new('svg')

        @field_array.each_index do |b|
          f = @field_array[b]
          next if f.lsb >= @visible_msb || f.msb < @visible_lsb
          if (!f.nil?) && (b == f.lsb)
            g = HtmlElement.new('g', {:class => "regFieldInternal regAttr_#{f.attr} regLink"})

            if f.lsb == f.msb
              text = HtmlElement.new('text',
                                     {:x => middle_of(f.lsb),
                                      :y => @cell_top - 4,
                                      :class => 'regBitNumMiddle'},
                                     [f.lsb.to_s])
              g.append(text)
            else
              if f.lsb < @visible_lsb
                g.add_class('regFieldOverflowLSB')
                g.append_element('text',
                                 {:x => right_of(f.lsb) + 2,
                                  :y => @cell_top - 4,
                                  :class => 'regBitNumEnd'},
                                 ["... " + f.lsb.to_s])
                g.append_element('text',
                                 {:x => middle_of(f.lsb),
                                  :y => @cell_top - 4,
                                  :class => 'regBitNumMiddle'},
                                 [@visible_lsb.to_s])
              else
                g.append_element('text',
                                 {:x => middle_of(f.lsb),
                                  :y => @cell_top - 4,
                                  :class => 'regBitNumMiddle'},
                                 [f.lsb.to_s])
              end
              if f.msb >= @visible_msb
                g.add_class('regFieldOverflowMSB')
                g.append_element('text',
                                 {:x => left_of(@visible_msb - 1) - 1,
                                  :y => @cell_top - 4,
                                  :class => 'regBitNumStart'},
                                 [f.msb.to_s + " ..."])
                g.append_element('text',
                                 {:x => middle_of(@visible_msb - 1),
                                  :y => @cell_top - 4,
                                  :class => 'regBitNumMiddle'},
                                 [(@visible_msb - 1).to_s])

              else
                g.append_element('text',
                                 {:x => middle_of(f.msb),
                                  :y => @cell_top - 4,
                                  :class => 'regBitNumMiddle'},
                                 [f.msb.to_s])
              end
              for i in (f.lsb + 1)..(f.msb - 1)
                if (i % 8) == 0 && i < @visible_msb && i >= @visible_lsb
                  g.append_element('text',
                                   {:x => middle_of(i),
                                    :y => @cell_top - 4,
                                    :class => 'regBitNumMiddle'},
                                   [i.to_s])
                end
                if (i % 8) == 7 && i < @visible_msb && i >= @visible_lsb
                  g.append_element('text',
                                   {:x => middle_of(i),
                                    :y => @cell_top - 4,
                                    :class => 'regBitNumMiddle'},
                                   [i.to_s])
                  g.append_element('line',
                                   {:x1 => left_of(i),
                                    :x2 => left_of(i),
                                    :y1 => @cell_top,
                                    :y2 => @cell_top - (@text_height * 0.4),
                                    :class => 'regBitNumLine'})
                end
              end
            end
            if f.lsb >= @visible_lsb
              g.append_element('line',
                               {:x1 => right_of(f.lsb),
                                :x2 => right_of(f.lsb),
                                :y1 => @cell_top,
                                :y2 => @cell_top - (@text_height * 0.75),
                                :class => (f.lsb == @visible_lsb) ? 'regBitNumLine' : 'regBitNumLineHide'})
            end
            if f.msb < @visible_msb
              g.append_element('line',
                               {:x1 => left_of(f.msb),
                                :x2 => left_of(f.msb),
                                :y1 => @cell_top,
                                :y2 => @cell_top - (@text_height * 0.75),
                                :class => 'regBitNumLine'})
            end
            g.add_class(f.add_class)
            g.add_class('regFieldUnused') if f.is_unused
            g.append_element('rect',
                             {:x => left_of(f.msb),
                              :y => @cell_top,
                              :width => right_of(f.lsb) - left_of(f.msb),
                              :height => @cell_height,
                              :class => 'regFieldBox'})
            if @debug
              print "visible_lsb=#{@visible_lsb}  visible_msb=#{@visible_msb}\n"
              print "fig_left=#{@fig_left}  max_fig_width=#{@max_fig_width}\n"
              print "reg rect f.lsb=#{f.lsb} f.msb=#{f.msb} width=#{right_of(f.lsb) - left_of(f.msb)} #{(right_of(f.lsb) - left_of(f.msb)) / @cell_width} bits\n"
              print "   left_of(#{f.lsb})=#{left_of(f.lsb)}\tright_of(#{f.lsb})=#{right_of(f.lsb)}\n"
              print "   left_of(#{f.msb})=#{left_of(f.msb)}\tright_of(#{f.msb})=#{right_of(f.msb)}\n\n"
            end
            for j in (f.lsb + 1)..f.msb
              if (j >= @visible_lsb) && (j <= @visible_msb)
                g.append_element('line',
                                 {:x1 => right_of(j),
                                  :x2 => right_of(j),
                                  :y1 => @cell_top + @cell_height - @cell_internal_height,
                                  :y2 => @cell_top + @cell_height,
                                  :class => 'regFieldBox'})
              end
            end
            g.append_element('text',
                             {:x => (left_of(f.msb) + right_of(f.lsb)) / 2,
                              :y => @cell_top - @bit_width_pos,
                              :class => 'regBitWidth'},
                             [(f.msb == f.lsb) ? '1 bit' : (f.msb - f.lsb + 1).to_s + ' bits'])

            if f.orig_name.nil?
              field_text = "#{f.name}"
            else
              field_text = "#{f.orig_name}"
            end
            if (!f.show_attr.nil?) && f.show_attr
              field_text = "#{field_text} (#{f.attr})"
            end
            text = HtmlElement.new('text',
                                   {:x => (left_of(f.msb) + right_of(f.lsb)) / 2,
                                    :y => @cell_top + @cell_name_top,
                                    :class => 'regFieldName'},
                                   [field_text])
            g.append(text)

            unless f.value.nil?
              if f.value.is_a?(Array) && (f.value.length == (f.msb - f.lsb + 1))
                for i in 0..f.value.length
                  if ((i + f.lsb) >= @visible_lsb) && ((i + f.lsb) < @visible_msb)
                    g.append_element('text',
                                     {:x => (left_of(f.lsb + i) + right_of(f.lsb + i)) / 2,
                                      :y => @cell_top + @cell_bit_value_top,
                                      :class => ('regFieldValue regFieldBitValue' + " regFieldBitValue-" + i.to_s + ((i == (f.value.length - 1)) ? " regFieldBitValue-msb" : ''))},
                                     [f.value[i]])

                  end
                end
              else
                if f.value.is_a?(String) || f.value.is_a?(Array)
                  g.append_element('text',
                                   {:x => (left_of(f.msb) + right_of(f.lsb >= @visible_lsb ? f.lsb : @visible_lsb)) / 2,
                                    :y => @cell_top + (f.msb == f.lsb ? @cell_bit_value_top : @cell_value_top),
                                    :class => 'regFieldValue'},
                                   [f.value])
                else
                  g.append_element('text',
                                   {:x => (left_of(f.msb) + right_of(f.lsb)) / 2,
                                    :y => @cell_top + @cell_value_top,
                                    :class => 'svg_error'},
                                   ['INVALID VALUE'])
                end
              end
            end

            # estimate text width when
            text_width = field_text.length * 8 # Assume 8px per character on average for 15px height chars
            if text_width > max_text_width
              max_text_width = text_width
            end
            text_height = @text_height
            if text_height == 0
              # bogus fix to guess width when clientHeight is 0 (e.g. IE10)
              text_height = 18 # Assume 18px: 1 row of text, 15px high
            end

            # if field has a specified value, the field name is too wide for the box, or the field name is too tall for the box
            if (f.lsb > @visible_msb) || (f.msb < @visible_lsb)
              g.delete_class('regFieldInternal')
              g.add_class('regFieldHidden')
            else
              if !((f.value == '') || (f.value == nil)) ||
                  ((text_width + 2) > (right_of(f.lsb) - left_of(f.msb))) ||
                  ((text_height + 2) > (@cell_height - @cell_internal_height))
                text.set(:x, right_of(-0.5))
                text.set(:y, next_bit_line)
                text.set(:class, 'regFieldName')
                p = PathElement.new({:class => 'regBitBracket',
                                     :fill => 'none'})
                p.move_to_abs(left_of(f.msb), @cell_top + @cell_height)
                p.line_to_rel(((right_of(f.lsb) - left_of(f.msb)) / 2), @bracket_height)
                p.line_to_abs(right_of(f.lsb), @cell_top + @cell_height)
                g.append(p)
                p = PathElement.new({:class => 'regBitLine',
                                     :fill => 'none'})
                p.move_to_abs(left_of(f.msb) + (right_of(f.lsb) - left_of(f.msb))/2, @cell_top + @cell_height + @bracket_height)
                p.line_to_vert_abs(next_bit_line - text_height / 4)
                p.line_to_horiz_abs(right_of(-0.4))
                g.append(p)
                g.delete_class('regFieldInternal')
                g.add_class("regFieldExternal regFieldExternal#{(bit_line_count < 2 ? '0' : '1')}")
                next_bit_line += text_height + 2
                bit_line_count = (bit_line_count + 1) % 4
              end
            end
            if f.msb > @visible_lsb && f.lsb < @visible_lsb
              g.append_element('text',
                               {:x => right_of(0) + 2,
                                :y => @cell_top + @cell_name_top,
                                :class => 'regFieldExtendsRight'},
                               ['...'])
            end
            if f.msb >= @visible_msb && f.lsb <= @visible_msb
              g.append_element('text',
                               {:x => left_of(f.msb) - 2,
                                :y => @cell_top + @cell_name_top,
                                :class => 'regFieldExtendsLeft'},
                               ['...'])
            end
            @svg.append(g)
          end
        end

        scale = 1.0
        max_text_width = max_text_width + right_of(-1)
        if @max_fig_width > 0 && max_text_width > @max_fig_width
          scale = @max_fig_width / max_text_width
        end
        @svg.attr = {:height => (scale * next_bit_line).to_s + 'px',
                     :width => (scale * max_text_width).to_s + 'px',
                     :view_box => '0 0 ' + max_text_width.to_s + ' ' + next_bit_line.to_s,
                     'xmlns:xlink'.intern => "http://www.w3.org/1999/xlink"}
      end
    end

    require 'asciidoctor'
    require 'asciidoctor/extensions'

    include ::Asciidoctor

    class RegisterBlock < Extensions::BlockProcessor

      use_dsl

      named :register
      on_context :paragraph, :listing
      parse_content_as :raw

      @@already_included = {}

      def include_link(parent, _attrs)
        return '' if @@already_included[parent.document]
        @@already_included[parent.document] = true
        css = <<-EOS
<style>
/* --- asciidoc-register-diagram.css --- */
text.regBitNumMiddle {
    text-anchor: middle;
    fill:        grey;
    font-family: "Source Sans Pro", Calibri, Tahoma, "Lucinda Grande", Arial, Helvetica, sans-serif;
    font-size:   8pt;
}

text.regBitNumEnd {
    text-anchor: end;
    fill:        grey;
    font-family: "Source Sans Pro", Calibri, Tahoma, "Lucinda Grande", Arial, Helvetica, sans-serif;
    font-size:   8pt;
}

text.regBitNumStart {
    text-anchor: start;
    fill:        grey;
    font-family: "Source Sans Pro", Calibri, Tahoma, "Lucinda Grande", Arial, Helvetica, sans-serif;
    font-size:   8pt;
}

text.regBitWidth {
    text-anchor: middle;
    fill:        none;
    font-family: "Source Sans Pro", Calibri, Tahoma, "Lucinda Grande", Arial, Helvetica, sans-serif;
    font-weight: bold;
    font-size:   11pt;
}

g line.regBitNumLine {
    stroke:       grey;
    stroke-width: 1px;
}

g line.regBitNumLine_Hide {
    stroke:       none;
    stroke-width: 1px;
}

g rect.regFieldBox {
    fill:         white;
    stroke:       black;
    stroke-width: 1.5px;
}

g.regAttr_rsvd rect.regFieldBox,
g.regAttr_rsvdp rect.regFieldBox,
g.regAttr_rsvdz rect.regFieldBox,
g.regAttr_reserved rect.regFieldBox,
g.regAttr_unused rect.regFieldBox {
    fill: white;
}

g.regFieldExternal line.regFieldBox,
g.regFieldInternal line.regFieldBox {
    stroke: black;
}

g.regFieldUnused line.regFieldBox {
    stroke: grey;
}

g.regFieldUnused text.regFieldName,
g.regFieldUnused text.regFieldValue {
    fill: grey;
}

g.regFieldHidden text.regFieldName,
g.regFieldHidden text.regFieldValue,
g.regFieldHidden path.regBitLine,
g.regFieldHidden path.regBitBracket,
g.regFieldHidden line.regFieldBox,
g.regFieldHidden rect.regFieldBox,
g.regFieldHidden line.regBitNumLine,
g.regFieldHidden line.regBitNumLine_Hide,
g.regFieldHidden text.regBitNumStart,
g.regFieldHidden text.regBitNumMiddle,
g.regFieldHidden text.regBitNumEnd,
g.regFieldHidden text.regFieldExtendsLeft,
g.regFieldHidden text.regFieldExtendsRight {
    fill:   none;
    stroke: none;
}

g text.regFieldValue,
g.regFieldInternal text.regFieldName {
    text-anchor: middle;
}

g.regFieldOverflowLSB text.regBitNumEnd,
g text.regFieldExtendsRight {
    text-anchor: start;
}

g.regFieldOverflowMSB text.regBitNumStart,
g text.regFieldExtendsLeft {
    text-anchor: end;
}

g text.regFieldName,
g text.regFieldValue {
    font-size:   11pt;
    font-family: "Source Sans Pro", Calibri, Tahoma, "Lucinda Grande", Arial, Helvetica, sans-serif;
}

g.regFieldExternal1 path.regBitLine,
g.regFieldExternal1 path.regBitBracket {
    stroke:       black;
    stroke-width: 1px;
}

g.regFieldExternal0 path.regBitLine {
    stroke:           green;
    stroke-dasharray: 4, 2;
    stroke-width:     1px;
}

g.regFieldExternal0 path.regBitBracket {
    stroke:       green;
    stroke-width: 1px;
}

svg text.regFieldValue {
    fill:        #0060A9;
    font-family: monospace;
}

svg.regpict {
    color: green;
}

svg *.svg_error text:not(.regBitWidth),
svg *.svg_error text:not(.regBitNumMiddle),
svg *.svg_error text:not(.regBitNumEnd),
svg *.svg_error text:not(.regBitNumStart) {
    fill:        red;
    font-size:   12pt;
    font-weight: bold;
    font-style:  normal;
    font-family: monospace;
}

figure div.json,
figure pre.json {
    color:   rgb(0, 90, 156);
    display: inherit;
}

@media screen {
    g.regLink:hover rect.regFieldBox,
    g.regLink:focus rect.regFieldBox { fill: #ffa; stroke: blue; }

    g.regLink:hover line.regBitNumLine,
    g.regLink:focus line.regBitNumLine,
    g.regLink:hover line.regBitNumLine_Hide,
    g.regLink:focus line.regBitNumLine_Hide,
    g.regLink:hover line.regFieldBox,
    g.regLink:focus line.regFieldBox,
    g.regLink:hover path.regBitLine,
    g.regLink:focus path.regBitLine,
    g.regLink.regFieldExternal:hover path.regBitBracket,
    g.regLink.regFieldExternal:focus path.regBitBracket { stroke: blue; }

    g.regLink:hover text.regFieldName,
    g.regLink:focus text.regFieldName,
    g.regLink.regFieldExternal:hover text.regFieldValue,
    g.regLink.regFieldExternal:focus text.regFieldValue { fill: blue; font-weight: bold; }

    g.regLink:hover text.regBitNumMiddle,
    g.regLink:focus text.regBitNumMiddle,
    g.regLink:hover text.regBitNumStart,
    g.regLink:focus text.regBitNumStart,
    g.regLink:hover text.regBitNumEnd,
    g.regLink:focus text.regBitNumEnd { fill: blue; font-weight: bold; font-size: 9pt; }

    g.regLink:hover text.regBitWidth,
    g.regLink:focus text.regBitWidth {
        fill: blue;
    }
}
</style>
        EOS
        css
      end

      def parse_blockdiag(lines)
        debug = 0
        raw = {}
        raw[:fields] = {}
        next_lsb = 0
        lines.each do |line|
          next if /^\s*(#|\/\/)/.match(line)
          if (m = /^\s*(['"]?)(\w+)\1\s*=\s*(['"]?)(.*)\3\s*((#|\/\/).*)?$/.match(line))
            puts "matched #1 #{line} match '#{m}'" if debug > 1
            raw[m[2].intern] = m[4]
            puts "raw='#{raw}'" if debug > 1
          elsif (m = /^\s*\*\s*(\[\s*((?<msb>\d+)\s*:)?\s*(?<lsb>\d+)\s*\])?\s*(?<quote>['"]?)(?<field>[-\/|*%$@&\[\]{}()!\w #]+)\k<quote>\s*(\[(?<options>.*)\])?\s*((#|\/\/).*)?$/.match(line))
            puts "matched #2 '#{line}' match '#{m}'" if debug > 1
            opts = {}
            unless m[:options].nil?
              temp = m[:options].split(',')
              puts "temp='#{temp}'" if debug > 1
              temp.each do |item|
                if (m2 = /\s*(?<quote>['"]?)(?<option>\w+)\k<quote>\s*(=\s*(?<quote2>['"]?)(?<option_value>.*)\k<quote2>)?\s*((#|\/\/).*)?$/.match(item))
                  puts "matched #3 '#{line}' match '#{m2}'" if debug > 1
                  if (val = m2[:option_value])
                    if /.*\|.*/.match(val)
                      val = m2[:option_value].split(/\|/)
                    end
                  else
                    val = true
                  end
                  opts[m2[:option].intern] = val
                else
                  puts "parse_blockdiag invalid option '#{item}'" if debug > 0
                  raise "parse_blockdiag invalid option '#{item}'"
                end
              end
            end
            puts "opts=#{opts} m[lsb]='#{m['lsb']}' m[msb]='#{m['msb']}'" if debug > 1
            if m[:lsb].nil? || m[:lsb] == ''
              opts[:lsb] = next_lsb
              opts[:msb] = next_lsb + (opts[:len] || 1).to_i - 1
            else
              opts[:lsb] = m[:lsb].to_i
              if m[:msb] && m[:msb] != ''
                opts[:msb] = m[:msb].to_i
              else
                opts[:msb] = opts[:lsb]
              end
            end
            next_lsb = opts[:msb] + 1
            puts "opts='#{opts}'" if debug > 1
            fname = m[:field].intern
            opts[:orig_name] = fname
            if raw[:fields][fname].nil?
              raw[:fields][fname] = opts
            else
              fname_index = 1
              until raw[:fields]["#{fname}_#{fname_index}"].nil?
                fname_index += 1
              end
              raw[:fields]["#{fname}_#{fname_index}"] = opts
            end
          else
            puts "parse_blockdiag unrecognized line '#{line}'" if debug > 0
            raise "parse_blockdiag unrecognized line '#{line}'"
          end
        end

        puts "parse_blockdiag: returning '#{raw}'" if debug > 0
        raw
      end

      def process parent, reader, attrs
        lines = reader.lines
        #puts '', '', 'RegisterBlock.process:', lines.join("\n"), ''
        raw = parse_blockdiag(lines)


        #print raw, "\n\n"
        #raw.each_pair { |key, value| print "raw[#{key}] = #{value}\n" }
        #raw["fields"].each_pair { |key, value| print "raw[fields.#{key}] = #{value}\n" }
        reg = RegisterDiagram.new(raw)
        #reg.dump
        reg.invent_unused
        reg.process
        #print reg.svg.dump
        block = create_block parent, :register, include_link(parent, attrs) + reg.svg.to_s, attrs, {:subs => nil}
        if attrs.has_key?('title')
          block.title = attrs.delete('title')
        end
        #block.assign_caption nil, 'figure'
        #puts "\nRegister: block.context=#{block.context} block.title=#{block.title} block.caption=#{block.caption} attrs=#{attrs}\n par=#{parent}"
        block
      end
    end

    Extensions.register do
      block RegisterBlock

    end
  end

end

require 'asciidoctor/converter/html5'

module Asciidoctor
  module Converter
    class Html5Converter
      def register node
        id_attribute = node.id ? %( id="#{node.id}") : nil
        title_element = node.title? ? %(<div class="title">#{node.captioned_title}</div>\n) : nil
        %(<div#{id_attribute} class="registerblock imageblock">
#{title_element}<div class="content">
#{node.content}
</div>
</div>)
      end
    end
  end
end

require 'asciidoctor/abstract_block'
require 'asciidoctor/block'
require 'asciidoctor/document'
require 'asciidoctor/list'
require 'asciidoctor/section'
require 'asciidoctor/table'

module Asciidoctor
  class AbstractBlock
# Public: Generate a caption and assign it to this block if one
# is not already assigned.
#
# If the block has a title and a caption prefix is available
# for this block, then build a caption from this information,
# assign it a number and store it to the caption attribute on
# the block.
#
# If an explicit caption has been specified on this block, then
# do nothing.
#
# key         - The prefix of the caption and counter attribute names.
#               If not provided, the name of the context for this block
#               is used. (default: nil).
#
# Returns nothing
    def assign_caption(caption = nil, key = nil)
      return unless title? || !@caption
      #puts "Enter assign_caption caption=#{caption} key=#{key} title=#{title}"

      if caption
        @caption = caption
        #puts "no caption"
      else
        if (value = @document.attributes['caption'])
          @caption = value
          #puts "document.attributes['caption'] #{@caption}"
        elsif title?
          key ||= @context.to_s
          caption_key = "#{key}-caption"
          #puts "caption_key=#{caption_key}"
          if (caption_title = @document.attributes[caption_key])
            #puts "caption_title=#{caption_title}"
            if caption_title.include?('%')
              caption_split = caption_title.split(/%/)
              #puts "\n#{caption_split}"
              caption_split.each_index do |i|
                item = caption_split[i]
                ##puts "index=#{i} item='#{item}'"
                if i != 0
                  #puts "i != 0 #{i}"
                  if caption_split[i].length == 0
                    caption_split[i] = '%'
                    #puts "length == 0 '#{caption_split[i]}'"
                  else
                    caption_split[i] = case item[0]
                                         when 'c'
                                           #puts "chapter + #{item}"
                                           #@document.reindex_sections
                                           sect = parent
                                           while sect.context != :section || sect.level != 1
                                             sect = sect.parent
                                           end
                                           #puts "\nsect=#{sect}\n par=#{sect.parent}\n    par.attributes=#{sect.parent.attributes}\n    sectnum=#{sect.sectnum('.', false)} index=#{sect.index} number=#{sect.number} sectname=#{sect.sectname} numbered=#{sect.numbered} title=#{title}\n    class=#{sect.class} node_name=#{sect.node_name} id=#{sect.id} context=#{sect.context} attributes=#{sect.attributes}"
                                           "#{sect.sectnum('.', false)}#{item[1..-1]}"
                                         when '#'
                                           caption_num = @document.counter_increment("#{key}-number", self)
                                           "#{caption_num}#{item[1..-1]}"
                                         when '('
                                           if (m1 = item.match(/\((\w+)\)(.*)/))
                                             #puts "match m1=#{m1} m1[1]=#{m1[1]} m1[2]=#{m1[2]}"
                                             key2 = "#{m1[1]}-number"
                                             #puts "key2=#{key2}"
                                             caption_num = @document.counter_increment(key2, self)
                                             "#{caption_num}#{m1[2]}"
                                           else
                                             "&lt;UNKNOWN COUNTER item='#{item}'&gt;"
                                           end
                                         else
                                           "&lt;UNKNOWN % ITEM '#{item[0]}&gt;'#{item[1..-1]}"
                                       end
                  end
                end
                #puts "#{caption_split}"
              end
              #puts "#{caption_split}"
              @caption = caption_split.join('')
            else
              caption_num = @document.counter_increment("#{key}-number", self)
              #puts "caption_num1=#{caption_num}"
              @caption = "#{caption_title} #{caption_num}. "
            end
          else
            caption_num = @document.counter_increment("#{key}-number", self)
            #puts "caption_num2=#{caption_num}"
            @caption = "#{caption_title} #{caption_num}. "
          end
        end
      end
      #puts "Exit assign_caption returning #{@caption}"
      nil
    end
  end
end

=begin
r1 = RegisterDiagram.new({ :width  => 16,
                           :fields => { :lowbit => { :lsb  => 0,
                                                     :attr => :RW },
                                        :byte   => { :lsb   => 1,
                                                     :msb   => 8,
                                                     :attr  => :RO,
                                                     :value => [0, 1, 0, 1, 0, 0, 1, 1] },
                                        :topbit => { :msb  => 15,
                                                     :attr => :RW1C } } })
r1.invent_unused
r1.process

=end

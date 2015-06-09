#!/usr/bin/ruby

class I3bangError < RuntimeError; end

def i3bang config, header = ''

    # kill comments; bangs in them interfere
    # also annoying trailing whitespace
    nobracket = config.include? '#!nobracket'
    config.gsub! /\s*#.*\n/, "\n"
    config.gsub! /\s+$/, ''

    # line continuations
    config.gsub! /\\\n\s*/, ''
    config += "\n"  # add back trailing newline

    # add notice
    # (feel free to remove/edit this; I don't mind)
    config = header + config

    # change shorthand format to expanded, regular format if specified
    # UGLY HACK WARNING: !!<...!...> can interfere, so we're going to take
    # all existing ![@!]?<...>'s out and put them back in later.
    # BUT, expansions might contain !... and !!...s as well, so we have to rerun
    # this upon every expansion. Therefore, this is stuck inside a method.
    def expand_nobracket config
        placeholder = '__PLCHLD__'
        ph_arr = []
        n = -1
        config.gsub!(/![@!]?<[^>]*>/) {|m|
            n += 1
            ph_arr.push m
            placeholder + "<#{n}>"
        }
        # now the actual substitutions
        config.gsub! /^\s*(![@!]?)([^<@!\n][^!\n]*)$/, '\1<\2>'
        config.gsub! /(![@!]?)([^<@!\s]\S*)/, '\1<\2>'
        # replace the placeholders
        config.gsub!(/#{placeholder}<(\d+)>/) { ph_arr[$1.to_i] }
    end
    expand_nobracket config if nobracket

    # first handle !@<...> sections
    i3bang_sections = Hash.new {|_, x|
        raise I3bangError, "unknown section #{x}"
    }
    config.gsub!(/!@<([^>]*)>/) {
        if $1.include? "\n"
            name, data = $1.split "\n", 2
            noecho = false
            if name[0] == '*'
                noecho = true
                name = name[1..-1]
            end
            i3bang_sections[name] = data
            noecho ? '' : data
        else
            i3bang_sections[$1]
        end
    }

    # then expand !!<...> into separate lines
    exrgx = /!!<([^>]*)>/
    while config =~ exrgx
        config.sub!(/^.*#{exrgx}.*$/) {|line|
            expansions = line.scan(exrgx).map{|expansion|
                group, values = expansion[0].split('!', 2)
                if values.nil?
                    values = group
                    group = "__default_group"
                end
                [group, values.gsub(/(\d+)\.\.(\d+)/) {
                    [*$1.to_i..$2.to_i] * ?,
                }.split(?,, -1)]
            }
            group = expansions[0][0]
            # equalize length of values for same groups
            maxlen = expansions.select{|g, _| g == group}.map(&:last).map(&:size).max
            expansions.map! {|g, values|
                g == group ?
                    [g, (values * (maxlen * 1.0 / values.length).ceil)[0...maxlen]] :
                    [g, values]
            }
            Array.new(expansions[0][1].length) { line.clone }.map {|l|
                idx = -1
                l.gsub(exrgx) {|m|
                    idx += 1
                    expansions[idx][0] == group ? expansions[idx][1].shift : m
                }
            }.join "\n"
        }
        expand_nobracket config if nobracket
    end

    # now replace all variables/math (!<...>) with their eval'd format
    i3bang_vars = Hash.new {|_, k|
        if k.is_a? Symbol
            raise I3bangError, "unknown variable #{k}"
        else
            k
        end
    }
    config.gsub!(/(?<!!)!<([^>]*)>/) {
        s = $1
        # Now we i3bang_eval s
        # http://en.wikipedia.org/wiki/Shunting-yard_algorithm
        # we assume everything is left-associative for simplicity

        # precedence and stacks setup
        prec = Hash.new {|_, x|
            if x.nil? || '()'.include?(x)
                -1
            else
                raise I3bangError, "unknown operator #{x}"
            end
        }.merge({
            '=' => 0,
            '+' => 1, '-' => 1,
            '*' => 2, '/' => 2, '%' => 2,
            '**' => 3
        })
        rpn = []
        opstack = []

        # tokenize input
        tokens = s.gsub(/\s/, '').scan(/
                        \w[\w\d]*     | # variable
                        \d+(?:\.\d+)? | # number literal
                        \*\*          | # multi-character operator
                        .               # other operator
                        /x)

        # Shunting-yard
        op = nil
        tokens.each do |t|
            case t[0]
            when 'a'..'z', 'A'..'Z', '_'  # variable
                rpn.push t.to_sym
            when '0'..'9'  # number literal
                rpn.push t.to_i
            when '('  # open paren
                opstack.push t
            when ')'  # close paren
                while (op = opstack.pop) != '('
                    raise I3bangError, 'mismatched parens' if op.nil?
                    rpn.push op
                end
            else  # operator
                rpn.push opstack.pop while prec[t] <= prec[opstack[-1]]
                opstack.push t
            end
        end
        rpn.push op while (op = opstack.pop)

        # evaluate rpn
        stack = []
        rpn.each do |t|
            case t
            when Fixnum, Symbol
                stack.push t
            when '='
                b, a = stack.pop, stack.pop
                i3bang_vars[a] = i3bang_vars[b]
            else
                b, a = stack.pop, stack.pop
                stack.push (case t
                            when '+' then ->a, b { a + b }
                            when '-' then ->a, b { a - b }
                            when '*' then ->a, b { a * b }
                            when '/' then ->a, b { a / b }
                            when '%' then ->a, b { a % b }
                            when '**' then ->a, b { a ** b }
                            when '(' then raise I3bangError, 'mismatched parens'
                           end)[i3bang_vars[a], i3bang_vars[b]]
            end
        end

        i3bang_vars[stack[0]]
    }

    # cleanup: remove empty lines
    config.gsub! /\n+/, "\n"
    config.sub! /\A\n/, ''

    config

end

if __FILE__ == $0
    fname = ARGV[0] || '_config'
    INFILE = File.expand_path "~/.i3/#{fname}"
    OUTFILE = File.expand_path '~/.i3/config'

    config = File.read INFILE
    File.write(OUTFILE, i3bang(config, "
    ##########
    # Generated via i3bang (https://github.com/KeyboardFire/i3bang).
    # Original file: #{fname}
    ##########\n"))
end

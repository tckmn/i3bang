#!/usr/bin/ruby

fname = ARGV[0] || '_config'
INFILE = File.expand_path "~/.i3/#{fname}"
OUTFILE = File.expand_path '~/.i3/config'

config = File.read INFILE

# kill comments; bangs in them interfere
nobracket = config.include? '#!nobracket'
config.gsub! /\s*#.*\n/, "\n"

# cleanup: remove empty lines
config.gsub! /\n+/, "\n"
config.sub! /\A\n/, ''

# add notice
# (feel free to remove/edit this; I don't mind)
config = "# Generated via i3bang (https://github.com/KeyboardFire/i3bang).
# Original file: #{fname}\n" + config

# change shorthand format to expanded, regular format if specified
config.gsub! /^\s*(![@!]?)([^<@!\n][^!\n]*)$/, '\1<\2>' if nobracket
config.gsub! /(![@!]?)([^<@!\s]\S*)/, '\1<\2>' if nobracket

# first replace all variables/math (!<...>) with their eval'd format
i3bang_vars = Hash.new {|_, k| k.is_a?(Symbol) ? nil : k }
config.gsub!(/(?<!!)!<([^>]*)>/) {
    s = $1
    # Now we i3bang_eval s
    # http://en.wikipedia.org/wiki/Shunting-yard_algorithm
    # we assume everything is left-associative for simplicity

    # precedence and stacks setup
    prec = Hash.new(-1).merge({
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
            rpn.push op while (op = opstack.pop) != '('
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
                       end)[i3bang_vars[a], i3bang_vars[b]]
        end
    end

    i3bang_vars[stack[0]]
}

# then handle !@<...> sections
i3bang_sections = Hash.new
config.gsub!(/!@<([^>]*)>/) {
    if $1.include? "\n"
        name, data = $1.split "\n", 2
        i3bang_sections[name] = data
    else
        i3bang_sections[$1]
    end
}

# now expand !!<...> into separate lines
exrgx = /!!<([^>]*)>/
while config =~ exrgx
    config.sub!(/^.*#{exrgx}.*$/) {|line|
        expansions = config.scan(exrgx).map.with_index{|expansion, idx|
            group, values = expansion[0].split('!', 2)
            if values == nil
                values = group
                group = "_auto_group_#{idx}"
            end
            [group, values.gsub(/(\d+)\.\.(\d+)/) {
                [*$1.to_i..$2.to_i] * ?,
            }.split(/, ?/)]
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
end

File.write OUTFILE, config

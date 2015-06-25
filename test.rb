#!/usr/bin/ruby

require_relative 'i3bang.rb'
require 'test/unit'

module Test::Unit::Assertions
    def assert_i3bang i3bang_in, i3bang_out, *a
        assert_equal i3bang("#!nobracket\n#{i3bang_in}").rstrip, i3bang_out, *a
    end

    def assert_i3bang_raise i3bang_in, *a
        assert_raise(I3bangError, *a) {
            i3bang "#!nobracket\n#{i3bang_in}"
        }
    end
end

class TestI3bang < Test::Unit::TestCase
    # a bit deceiving of a name; not all of these are strict identity
    def test_identity
        assert_i3bang 'test', 'test'
        assert_i3bang "foo\nbar\nbaz", "foo\nbar\nbaz"
        assert_i3bang "foo#!<1+>!!<a,b,c>\nbar", "foo\nbar"
        assert_i3bang "foo  \nbar\t  \t ", "foo\nbar"
    end

    def test_variables
        assert_i3bang '!<a=42>!a', '42'
        assert_i3bang '!<foo = 1>!<bar = 2>!<foo>!<bar>', '12'
        assert_i3bang "!n=1337\n!n", '1337'
    end

    def test_math_operations
        assert_i3bang '!22+20', '42'
        assert_i3bang '!6*9', '54'  # nice try, we're not in base 13
        assert_i3bang '!200-13', '187'
        assert_i3bang '!8/3', '2'  # int division
        assert_i3bang '!8%3', '2'
        assert_i3bang '!2**8', '256'
    end

    def test_math_precedence
        assert_i3bang '!5+6*7', '47'
        assert_i3bang '!(5+6)*7', '77'
        assert_i3bang '!<a=1+2*3-4/5**6>!a', '7'
    end

    def test_math_errors
        assert_i3bang_raise '!thisdoesntexist'
        assert_i3bang_raise '!2$2'
        assert_i3bang_raise '!((1+1)'
        assert_i3bang_raise '!(1+1))'
        assert_i3bang_raise '!1+'
    end

    def test_basic_expansions
        assert_i3bang 'b!!<a,o,i,u>t', "bat\nbot\nbit\nbut"
        assert_i3bang 'e!!at,xterminate,xamine potatoes',
            "eat potatoes\nexterminate potatoes\nexamine potatoes"
        assert_i3bang 'pi!!e,ll,e,e,', "pie\npill\npie\npie\npi"
    end

    def test_range_expansions
        assert_i3bang 'test !!8..11', "test 8\ntest 9\ntest 10\ntest 11"
        assert_i3bang 'fizz!!1..4,buzz,6..7',
            "fizz1\nfizz2\nfizz3\nfizz4\nfizzbuzz\nfizz6\nfizz7"
        assert_i3bang '!!1,3..5,8,10..13', "1\n3\n4\n5\n8\n10\n11\n12\n13"
    end

    def test_dual_expansions
        assert_i3bang 'bind !!1..9,0 workspace !!1..10',
            "bind 1 workspace 1\n" + "bind 2 workspace 2\n" +
            "bind 3 workspace 3\n" + "bind 4 workspace 4\n" +
            "bind 5 workspace 5\n" + "bind 6 workspace 6\n" +
            "bind 7 workspace 7\n" + "bind 8 workspace 8\n" +
            "bind 9 workspace 9\n" + "bind 0 workspace 10"
        assert_i3bang '!!<a,b,c,d,e>!!1,2,3', "a1\nb2\nc3\nd1\ne2"
        assert_i3bang '!!<foo!a,b>!!foo!4,5,6,7', "a4\nb5\na6\nb7"
        assert_i3bang '!!<1,2,3>!!<4,5>!!<6,7,8,9>!!<10>',
            "14610\n25710\n34810\n15910"
    end

    def test_separate_expansions
        assert_i3bang '!!<1!a,b,c>!!2!1,2', "a1\na2\nb1\nb2\nc1\nc2"
        assert_i3bang '!!<foo,bar>!!x!1,2', "foo1\nfoo2\nbar1\nbar2"
        assert_i3bang '!!<foo!i,j>!!3,4', "i3\ni4\nj3\nj4"
    end

    def test_multiple_expansion_groups
        assert_i3bang '!!<A!a,b,c>!!A!1,2,3 !!<B!d,e>!!B!4,5',
            "a1 d4\na1 e5\nb2 d4\nb2 e5\nc3 d4\nc3 e5"
        assert_i3bang '!!<a,b,c>!!1,2 !!<x!x,y,z>!!x!3,4',
            "a1 x3\na1 y4\na1 z3\nb2 x3\nb2 y4\nb2 z3\nc1 x3\nc1 y4\nc1 z3"
        assert_i3bang '!!<4,7>!!<2,9,5>!!<x!,.>!!<0,12>',
            "420\n42.0\n7912\n79.12\n450\n45.0"
    end

    def test_sections
        assert_i3bang "!@<foo\nfoo\nbar\nbaz>\n!@foo",
            "foo\nbar\nbaz\nfoo\nbar\nbaz"
        assert_i3bang "!@<*a\nblah>\nfoo !@a baz", 'foo blah baz'
        assert_i3bang "!@<+foo\n!<1+1>\n>\n!@foo", "2\n2"
    end

    def test_section_errors
        assert_i3bang_raise "!@thisdoesntexist"
    end

    def test_conditionals
        ENV['foo'] = 'bar'
        assert_i3bang "!?<foo=bar\nbaz\n>", 'baz'
        assert_i3bang "!?<foo=baz\nbar\n>", ''
    end

    def test_conditional_errors
        assert_i3bang_raise "!?<\n>"
        assert_i3bang_raise "!?<foo\nbar\nbaz\n>"
    end

    def test_line_continuations
        assert_i3bang "foo\\\nbar", 'foobar'
        assert_i3bang "foo  \\\n     bar", 'foo  bar'
        assert_i3bang "foo\nbar\\\nbaz\\\nqux\nquux", "foo\nbarbazqux\nquux"
        assert_i3bang "foo \\   #comment\nbar", 'foo bar'
    end

    def test_bang_parsing
        assert_i3bang '!  1     +   1', '2'
        assert_i3bang "!@<!!!\n!!!!!>!@<!!!>", '!!!!!!!!!!'
        assert_i3bang '!1+1 + 2      ', '4'
        assert_i3bang '   !1+1 + 2   ', '4'
        assert_i3bang '_!1+1 + 2     ', '_2 + 2'
    end
end

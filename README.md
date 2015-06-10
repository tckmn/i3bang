# i3bang

A preprocessor for i3 config files aimed to drastically reduce their length.

## Examples

A full config file that employs heavy use of i3bang [can be found in my dotfiles
repo](https://github.com/KeyboardFire/dotfiles/blob/master/.i3/_config), and
indeed is my own. In my obviously unbiased and completely objective opinion, it
is elegant and beautiful. ;)

Here are a few select snippets:

---

Very simple expansions:

    bindsym !!Return,Escape,space,$mod+r mode "default"

becomes

    bindsym Return mode "default"
    bindsym Escape mode "default"
    bindsym space mode "default"
    bindsym $mod+r mode "default"

---

Dual expansions and line continuation:

    bindsym $mod+!!q,w,e \                      # change container layout
      layout !!<stacking,tabbed,toggle split>

becomes

    bindsym $mod+q layout stacking
    bindsym $mod+w layout tabbed
    bindsym $mod+e layout toggle split

---

Separate expansions:

    bindsym $mod!!<2!,+Shift>+!!1!1..9,0 \      # workspaces!
      !!<2!,move container to >\
      workspace number !!1!1..10

becomes

    bindsym $mod+1 workspace number 1
    bindsym $mod+2 workspace number 2
    bindsym $mod+3 workspace number 3
    bindsym $mod+4 workspace number 4
    bindsym $mod+5 workspace number 5
    bindsym $mod+6 workspace number 6
    bindsym $mod+7 workspace number 7
    bindsym $mod+8 workspace number 8
    bindsym $mod+9 workspace number 9
    bindsym $mod+0 workspace number 10
    bindsym $mod+Shift+1 move container to workspace number 1
    bindsym $mod+Shift+2 move container to workspace number 2
    bindsym $mod+Shift+3 move container to workspace number 3
    bindsym $mod+Shift+4 move container to workspace number 4
    bindsym $mod+Shift+5 move container to workspace number 5
    bindsym $mod+Shift+6 move container to workspace number 6
    bindsym $mod+Shift+7 move container to workspace number 7
    bindsym $mod+Shift+8 move container to workspace number 8
    bindsym $mod+Shift+9 move container to workspace number 9
    bindsym $mod+Shift+0 move container to workspace number 10

---

Variables and sections:

    !@<*mousemove
    exec xdotool mousemove_relative !!1!-!s,0,0,!s,-!s,!s,-!s,!s \
                                    !!1!0,!s,-!s,-,-!s,-!s,!s,!s>
    mode "mouse" {
            !s = 20  # hjkl speed
            bindsym !!1!h,j,k,l,y,u,b,n !@mousemove
            !s = 8  # numpad speed
            bindsym KP_!!1!4,2,8,6,7,9,1,3 !@mousemove

becomes

    mode "mouse" {
            bindsym h exec xdotool mousemove_relative -20 0
            bindsym j exec xdotool mousemove_relative 0 20
            bindsym k exec xdotool mousemove_relative 0 -20
            bindsym l exec xdotool mousemove_relative 20 -
            bindsym y exec xdotool mousemove_relative -20 -20
            bindsym u exec xdotool mousemove_relative 20 -20
            bindsym b exec xdotool mousemove_relative -20 20
            bindsym n exec xdotool mousemove_relative 20 20
            bindsym KP_4 exec xdotool mousemove_relative -8 0
            bindsym KP_2 exec xdotool mousemove_relative 0 8
            bindsym KP_8 exec xdotool mousemove_relative 0 -8
            bindsym KP_6 exec xdotool mousemove_relative 8 -
            bindsym KP_7 exec xdotool mousemove_relative -8 -8
            bindsym KP_9 exec xdotool mousemove_relative 8 -8
            bindsym KP_1 exec xdotool mousemove_relative -8 8
            bindsym KP_3 exec xdotool mousemove_relative 8 8

---

Environment variable conditionals:

    !?<USER=someusername
      ...
    >

This will only add the content inside the conditional to your config file if
i3bang is run by user "someusername."

---

Raw sections:

    !@<+default_keybindings
      ...  # (you can have !!<expansions> and !<math> inside here)
    >

    mode "foo" {
            ...
            !@default_keybindings
    }

This allows you to keep your default mode keybindings in different modes. When
you prepend a `+` to a section's name, it is interpreted as meaning "raw mode,"
which means that a.) all `!!<expansions>` and `!<math>` is treated as it
normally would, and b.) only a `>` on its own line can end the section
(allowing you to still be able to use `!!<expansions>`/`!<math>` with brackets.
Hence, you can simply wrap all your default keybindings in a
`!@<+default_keybindings ... >`, and then stick a `!@default_keybindings` at
the end of every mode that you want to keep them in (put it at the end because
for some reason keybindings that come *first* take precedence and override
bindings to the same key that come later).

## Usage

1. Place `i3bang.rb` in your `~/.i3` (copy it there, move it there, or make a
   symlink).

2. Rename your `config` file to something else (mine is `_config`).

3. When you want to generate the normal `config` file, run `./i3bang.rb
   _config` (or whatever you named your non-preprocessed config file).

4. (recommended) Change this line in your i3 config file:

        bindsym $mod+Shift+c reload

    to this:

        bindsym $mod+Shift+c exec ~/.i3/i3bang.rb _config; reload

    in order to automatically preprocess the config file whenever you reload
    your config (hit mod+shift+c).

## Advanced Examples

Advanced line continuations + expansions, plus math:

    bindsym Alt_L !!<\>
      exec echo !!1..9,0 | dzen2 -x 175 -y !<55+40*!!<0..9>> -w 30 -h 30 -p 1; !!<\>
      nop

becomes

    bindsym Alt_L exec echo 1 | dzen2 -x 175 -y 55 -w 30 -h 30 -p 1; exec echo 2 | dzen2 -x 175 -y 95 -w 30 -h 30 -p 1; exec echo 3 | dzen2 -x 175 -y 135 -w 30 -h 30 -p 1; exec echo 4 | dzen2 -x 175 -y 175 -w 30 -h 30 -p 1; exec echo 5 | dzen2 -x 175 -y 215 -w 30 -h 30 -p 1; exec echo 6 | dzen2 -x 175 -y 255 -w 30 -h 30 -p 1; exec echo 7 | dzen2 -x 175 -y 295 -w 30 -h 30 -p 1; exec echo 8 | dzen2 -x 175 -y 335 -w 30 -h 30 -p 1; exec echo 9 | dzen2 -x 175 -y 375 -w 30 -h 30 -p 1; exec echo 0 | dzen2 -x 175 -y 415 -w 30 -h 30 -p 1; nop

Note that `!!<\>` acts as a line continuation that is only applied after
expansions have been... expanded. This is helpful for expanding many actions to
a single `bindsym`, which requires each separate command to be
semicolon-separated on the same line.

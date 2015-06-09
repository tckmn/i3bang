# i3bang

A preprocessor for i3 config files aimed to drastically reduce their length.

## Examples

TODO

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

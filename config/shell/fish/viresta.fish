# Viresta's prompt and autocomplete color for Fish.

status is-interactive; or return

# Someone with their own prompt keeps it. The plain text login has no Nerd Font.
if test "$TERM" != linux
    and command -q starship
    and not test -f "$__fish_config_dir/functions/fish_prompt.fish"
    and not functions -q _tide_prompt
    starship init fish | source
end

# Only over Fish's default, so a color someone chose stays. Color 8 comes from the
# terminal, so it follows the dark and light themes.
if not set -q fish_color_autosuggestion
    or test "$fish_color_autosuggestion" = "555 brblack"
    set -g fish_color_autosuggestion brblack
end

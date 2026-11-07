# Viresta's prompt, autocomplete color and update command for Fish.

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

# CachyOS has its own update shortcut, which ranks the mirrors and runs pacman, and it
# hides Viresta's update command. CachyOS sets it in config.fish, which Fish runs after
# this file, so it is removed at the first prompt instead. Only CachyOS's one goes, and
# only while Viresta's command is there, so turning that off brings it back.
function __viresta_update_command --on-event fish_prompt
    functions -e __viresta_update_command
    set -l command (command -s update)
    if test -n "$command"
        and grep -qs 'viresta update' $command
        and functions -q update
        and string match -q '*cachyos-rate-mirrors*' -- (functions update)
        functions -e update
    end
end

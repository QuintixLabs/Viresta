# viresta.fish
# Tab completion for the viresta command in Fish. The options come from each script's own
# help, so a new option shows up here without being listed.

complete -c viresta -f

complete -c viresta -n __fish_use_subcommand -a install -d "Run the install again, with the menu"
complete -c viresta -n __fish_use_subcommand -a update -d "Update Viresta"
complete -c viresta -n __fish_use_subcommand -a uninstall -d "Remove Viresta"
complete -c viresta -n __fish_use_subcommand -l version -s v -d "Show the installed version"
complete -c viresta -n __fish_use_subcommand -l help -s h -d "Show this help"

complete -c viresta -n "__fish_seen_subcommand_from install update uninstall" \
    -a "(viresta (commandline -opc)[2] --help 2>/dev/null | string match -rg -- '^\s+(?:-\w, )?(--[a-z-]+)')"

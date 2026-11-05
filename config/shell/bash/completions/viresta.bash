# shellcheck shell=bash

# viresta.bash
# Tab completion for the viresta command in Bash. bash-completion loads it the first time
# viresta is typed. The options come from each script's own help, so a new option shows up
# here without being listed.

_viresta() {
    local current="${COMP_WORDS[COMP_CWORD]}"
    local words

    if [ "$COMP_CWORD" -eq 1 ]; then
        words="install update uninstall --version --help"
    else
        case "${COMP_WORDS[1]}" in
            install|update|uninstall)
                words="$(viresta "${COMP_WORDS[1]}" --help 2>/dev/null \
                    | grep -oE '^ +(-[a-z], )?--[a-z-]+' | grep -oE -- '--[a-z-]+')"
                ;;
            *) return 0 ;;
        esac
    fi

    mapfile -t COMPREPLY < <(compgen -W "$words" -- "$current")
}

complete -F _viresta viresta

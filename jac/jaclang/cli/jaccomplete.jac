"""Shell completion script generation for bash, zsh, and fish."""

"""Generate a static shell completion script from pre-processed command data."""
def static_shellcode(
    commands: list, executable: str = "jac", shell: str = "bash"
) -> str;

def _static_bash(commands: list, exe: str) -> str;

def _static_zsh(commands: list, exe: str) -> str;

def _static_fish(commands: list, exe: str) -> str;

glob _BASH_TEMPLATE = (
         '_%s_complete() {\n'
         '    local cur prev cmd\n'
         '    COMPREPLY=()\n'
         '    cur="${COMP_WORDS[COMP_CWORD]}"\n'
         '    prev="${COMP_WORDS[COMP_CWORD-1]}"\n'
         '    cmd="${COMP_WORDS[1]}"\n'
         '\n'
         '    if [[ $COMP_CWORD -eq 1 ]]; then\n'
         '        COMPREPLY=($(compgen -W "%s" -- "$cur"))\n'
         '        return\n'
         '    fi\n'
         '\n'
         '%s'
         '    case "$cmd" in\n'
         '%s\n'
         '    esac\n'
         '}\n'
         'complete -o default -o bashdefault'
         ' -F _%s_complete %s\n'
     ),
     _BASH_VALUE_BLOCK = (
         '    # Complete option values\n'
         '    case "$cmd" in\n'
         '%s\n'
         '    esac\n'
         '\n'
     ),
     _BASH_VALUE_CASE = (
         '        %s)\n'
         '            case "$prev" in\n'
         '%s\n'
         '            esac\n'
         '            ;;'
     ),
     _BASH_CMD_WITH_FILES = (
         '        %s)\n'
         '            case "$cur" in\n'
         '                -*) COMPREPLY=($(compgen'
         ' -W "%s" -- "$cur")) ;;\n'
         '            esac\n'
         '            ;;'
     ),
     _BASH_CMD_NO_FILES = (
         '        %s)\n'
         '            COMPREPLY=($(compgen'
         ' -W "%s" -- "$cur"))\n'
         '            ;;'
     ),
     _ZSH_TEMPLATE = (
         '#compdef %s\n'
         '_%s() {\n'
         '    local -a commands\n'
         '    commands=(\n'
         '%s\n'
         '    )\n'
         '\n'
         '    _arguments -C \\\n'
         '        \'1:command:->command\' \\\n'
         '        \'*::arg:->args\'\n'
         '\n'
         '    case $state in\n'
         '        command)\n'
         '            _describe \'command\' commands\n'
         '            ;;\n'
         '        args)\n'
         '            case $words[1] in\n'
         '%s\n'
         '            esac\n'
         '            ;;\n'
         '    esac\n'
         '}\n'
         '_%s "$@"\n'
     );

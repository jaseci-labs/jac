import from typing { cast }

def static_shellcode(
    commands: list[dict[str, any]], executable: str = "jac", shell: str = "bash"
) -> str;

def _static_bash(commands: list[dict[str, any]], exe: str) -> str;

def _static_zsh(commands: list[dict[str, any]], exe: str) -> str;

def _static_fish(commands: list[dict[str, any]], exe: str) -> str;

glob _BASH_TEMPLATE = '_%s_complete() {\n' ' -F _%s_complete %s\n',
     _BASH_VALUE_BLOCK = '    # Complete option values\n' '\n',
     _BASH_VALUE_CASE = '        %s)\n' '            ;;',
     _BASH_CMD_WITH_FILES = '        %s)\n' '            ;;',
     _BASH_CMD_NO_FILES = '        %s)\n' '            ;;',
     _ZSH_TEMPLATE = '#compdef %s\n' '_%s "$@"\n';

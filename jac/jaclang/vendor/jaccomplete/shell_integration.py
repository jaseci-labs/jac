"""Shell completion script templates for bash, zsh, fish, tcsh, and powershell."""

from shlex import quote

_BASH = r"""#compdef %(executables)s
__jac_complete_run() {
    if [[ -z "${JAC_COMPLETE_USE_TEMPFILES-}" ]]; then
        __jac_complete_run_inner "$@"; return
    fi
    local tmpfile="$(mktemp)"
    _JAC_COMPLETE_STDOUT_FILENAME="$tmpfile" __jac_complete_run_inner "$@"
    local code=$?; cat "$tmpfile"; rm "$tmpfile"; return $code
}
__jac_complete_run_inner() {
    if [[ -z "${_JAC_DEBUG-}" ]]; then
        "$@" 8>&1 9>&2 1>/dev/null 2>&1 </dev/null
    else
        "$@" 8>&1 9>&2 1>&9 2>&1 </dev/null
    fi
}
_jac_complete%(function_suffix)s() {
    local IFS=$'\013'
    local script="%(script)s"
    if [[ -n "${ZSH_VERSION-}" ]]; then
        local completions
        completions=($(IFS="$IFS" \
            COMP_LINE="$BUFFER" COMP_POINT="$CURSOR" \
            _JAC_COMPLETE=1 _JAC_COMPLETE_SHELL="zsh" \
            _JAC_COMPLETE_SUPPRESS_SPACE=1 \
            __jac_complete_run ${script:-${words[1]}}))
        local nosort=() nospace=()
        is-at-least 5.8 && nosort=(-o nosort)
        [[ "${completions-}" =~ ([^\\\\]): && "${match[1]}" =~ [=/:] ]] && nospace=(-S '')
        _describe "${words[1]}" completions "${nosort[@]}" "${nospace[@]}"
    else
        local SUPPRESS_SPACE=0
        compopt +o nospace 2>/dev/null && SUPPRESS_SPACE=1
        COMPREPLY=($(IFS="$IFS" \
            COMP_LINE="$COMP_LINE" COMP_POINT="$COMP_POINT" COMP_TYPE="$COMP_TYPE" \
            _JAC_COMPLETE_COMP_WORDBREAKS="$COMP_WORDBREAKS" \
            _JAC_COMPLETE=1 _JAC_COMPLETE_SHELL="bash" \
            _JAC_COMPLETE_SUPPRESS_SPACE=$SUPPRESS_SPACE \
            __jac_complete_run ${script:-$1}))
        [[ $? != 0 ]] && unset COMPREPLY
        [[ $SUPPRESS_SPACE == 1 && "${COMPREPLY-}" =~ [=/:]$ ]] && compopt -o nospace
    fi
}
if [[ -z "${ZSH_VERSION-}" ]]; then
    complete %(complete_opts)s -F _jac_complete%(function_suffix)s %(executables)s
else
    autoload is-at-least
    if [[ $zsh_eval_context == *func ]]; then
        _jac_complete%(function_suffix)s "$@"
    else
        compdef _jac_complete%(function_suffix)s %(executables)s
    fi
fi
"""

_FISH = r"""
function __fish_%(function_name)s_complete
    set -lx _JAC_COMPLETE 1
    set -lx _JAC_COMPLETE_IFS \n
    set -lx _JAC_COMPLETE_SUPPRESS_SPACE 1
    set -lx _JAC_COMPLETE_SHELL fish
    set -lx COMP_LINE (commandline -p)
    set -lx COMP_POINT (string length (commandline -cp))
    if set -q _JAC_DEBUG
        %(script)s 8>&1 9>&2 1>&9 2>&1
    else
        %(script)s 8>&1 9>&2 1>/dev/null 2>&1
    end
end
complete %(completion_arg)s %(executable)s -f -a '(__fish_%(function_name)s_complete)'
"""

_POWERSHELL = r"""
Register-ArgumentCompleter -Native -CommandName %(executable)s -ScriptBlock {
    param($commandName, $wordToComplete, $cursorPosition)
    $completion_file = New-TemporaryFile
    $env:JAC_COMPLETE_USE_TEMPFILES = 1
    $env:_JAC_COMPLETE_STDOUT_FILENAME = $completion_file
    $env:COMP_LINE = $wordToComplete
    $env:COMP_POINT = $cursorPosition
    $env:_JAC_COMPLETE = 1
    $env:_JAC_COMPLETE_SUPPRESS_SPACE = 0
    $env:_JAC_COMPLETE_IFS = "`n"
    $env:_JAC_COMPLETE_SHELL = "powershell"
    %(script)s 2>&1 | Out-Null
    Get-Content $completion_file | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_JAC_COMPLETE_STDOUT_FILENAME, Env:\JAC_COMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_JAC_COMPLETE, Env:\_JAC_COMPLETE_SUPPRESS_SPACE, Env:\_JAC_COMPLETE_IFS, Env:\_JAC_COMPLETE_SHELL
}
"""  # noqa: E501

_TCSH = 'complete "%(executable)s" \'p@*@`jac-complete-tcsh "%(script)s"`@\' ;'

_TEMPLATES = {"bash": _BASH, "zsh": _BASH, "fish": _FISH, "powershell": _POWERSHELL, "tcsh": _TCSH}


def shellcode(executables, use_defaults=True, shell="bash", complete_arguments=None, jaccomplete_script=None):
    """Generate shell completion registration code for the given executables."""
    script = jaccomplete_script or ""
    complete_opts = (
        " ".join(complete_arguments) if complete_arguments
        else "-o nospace -o default -o bashdefault" if use_defaults
        else "-o nospace -o bashdefault"
    )

    if shell in ("bash", "zsh"):
        execs = " ".join(quote(e) for e in executables)
        suffix = ("_" + script.replace(" ", "_SPACE_")) if script else ""
        return _BASH % dict(
            complete_opts=complete_opts, executables=execs,
            script=script, function_suffix=suffix,
        )

    code = ""
    for exe in executables:
        s = script or exe
        if shell == "fish":
            code += _FISH % dict(
                executable=exe, script=s,
                completion_arg="--path" if "/" in exe else "--command",
                function_name=exe.replace("/", "_"),
            )
        elif shell == "powershell":
            code += _POWERSHELL % dict(executable=exe, script=s)
        else:
            tmpl = _TEMPLATES.get(shell, "")
            if tmpl:
                code += tmpl % dict(executable=exe, script=s)
    return code
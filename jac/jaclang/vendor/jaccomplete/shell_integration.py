from shlex import quote

bashcode = r"""#compdef %(executables)s
# Run something, muting output or redirecting it to the debug stream
# depending on the value of _ARC_DEBUG.
# If JAC_COMPLETE_USE_TEMPFILES is set, use tempfiles for IPC.
__jac_complete_run() {
    if [[ -z "${JAC_COMPLETE_USE_TEMPFILES-}" ]]; then
        __jac_complete_run_inner "$@"
        return
    fi
    local tmpfile="$(mktemp)"
    _JAC_COMPLETE_STDOUT_FILENAME="$tmpfile" __jac_complete_run_inner "$@"
    local code=$?
    cat "$tmpfile"
    rm "$tmpfile"
    return $code
}

__jac_complete_run_inner() {
    if [[ -z "${_ARC_DEBUG-}" ]]; then
        "$@" 8>&1 9>&2 1>/dev/null 2>&1 </dev/null
    else
        "$@" 8>&1 9>&2 1>&9 2>&1 </dev/null
    fi
}

_jac_complete%(function_suffix)s() {
    local IFS=$'\013'
    local script="%(jaccomplete_script)s"
    if [[ -n "${ZSH_VERSION-}" ]]; then
        local completions
        completions=($(IFS="$IFS" \
            COMP_LINE="$BUFFER" \
            COMP_POINT="$CURSOR" \
            _JAC_COMPLETE=1 \
            _JAC_COMPLETE_SHELL="zsh" \
            _JAC_COMPLETE_SUPPRESS_SPACE=1 \
            __jac_complete_run ${script:-${words[1]}}))
        local nosort=()
        local nospace=()
        if is-at-least 5.8; then
            nosort=(-o nosort)
        fi
        if [[ "${completions-}" =~ ([^\\\\]): && "${match[1]}" =~ [=/:] ]]; then
            nospace=(-S '')
        fi
        _describe "${words[1]}" completions "${nosort[@]}" "${nospace[@]}"
    else
        local SUPPRESS_SPACE=0
        if compopt +o nospace 2> /dev/null; then
            SUPPRESS_SPACE=1
        fi
        COMPREPLY=($(IFS="$IFS" \
            COMP_LINE="$COMP_LINE" \
            COMP_POINT="$COMP_POINT" \
            COMP_TYPE="$COMP_TYPE" \
            _JAC_COMPLETE_COMP_WORDBREAKS="$COMP_WORDBREAKS" \
            _JAC_COMPLETE=1 \
            _JAC_COMPLETE_SHELL="bash" \
            _JAC_COMPLETE_SUPPRESS_SPACE=$SUPPRESS_SPACE \
            __jac_complete_run ${script:-$1}))
        if [[ $? != 0 ]]; then
            unset COMPREPLY
        elif [[ $SUPPRESS_SPACE == 1 ]] && [[ "${COMPREPLY-}" =~ [=/:]$ ]]; then
            compopt -o nospace
        fi
    fi
}
if [[ -z "${ZSH_VERSION-}" ]]; then
    complete %(complete_opts)s -F _jac_complete%(function_suffix)s %(executables)s
else
    # When called by the Zsh completion system, this will end with
    # "loadautofunc" when initially autoloaded and "shfunc" later on, otherwise,
    # the script was "eval"-ed so use "compdef" to register it with the
    # completion system
    autoload is-at-least
    if [[ $zsh_eval_context == *func ]]; then
        _jac_complete%(function_suffix)s "$@"
    else
        compdef _jac_complete%(function_suffix)s %(executables)s
    fi
fi
"""

tcshcode = """\
complete "%(executable)s" 'p@*@`jac-complete-tcsh "%(jaccomplete_script)s"`@' ;
"""

fishcode = r"""
function __fish_%(function_name)s_complete
    set -lx _JAC_COMPLETE 1
    set -lx _JAC_COMPLETE_DFS \t
    set -lx _JAC_COMPLETE_IFS \n
    set -lx _JAC_COMPLETE_SUPPRESS_SPACE 1
    set -lx _JAC_COMPLETE_SHELL fish
    set -lx COMP_LINE (commandline -p)
    set -lx COMP_POINT (string length (commandline -cp))
    set -lx COMP_TYPE
    if set -q _ARC_DEBUG
        %(jaccomplete_script)s 8>&1 9>&2 1>&9 2>&1
    else
        %(jaccomplete_script)s 8>&1 9>&2 1>/dev/null 2>&1
    end
end
complete %(completion_arg)s %(executable)s -f -a '(__fish_%(function_name)s_complete)'
"""

powershell_code = r"""
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
    %(jaccomplete_script)s 2>&1 | Out-Null

    Get-Content $completion_file | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, "ParameterValue", $_)
    }
    Remove-Item $completion_file, Env:\_JAC_COMPLETE_STDOUT_FILENAME, Env:\JAC_COMPLETE_USE_TEMPFILES, Env:\COMP_LINE, Env:\COMP_POINT, Env:\_JAC_COMPLETE, Env:\_JAC_COMPLETE_SUPPRESS_SPACE, Env:\_JAC_COMPLETE_IFS, Env:\_JAC_COMPLETE_SHELL
}
"""  # noqa: E501

shell_codes = {"bash": bashcode, "tcsh": tcshcode, "fish": fishcode, "powershell": powershell_code}


def shellcode(executables, use_defaults=True, shell="bash", complete_arguments=None, jaccomplete_script=None):
    """
    Provide the shell code required to register a python executable for use with the jaccomplete module.

    :param list(str) executables: Executables to be completed (when invoked exactly with this name)
    :param bool use_defaults: Whether to fallback to readline's default completion when no matches are generated
        (affects bash only)
    :param str shell: Name of the shell to output code for
    :param complete_arguments: Arguments to call complete with (affects bash only)
    :type complete_arguments: list(str) or None
    :param jaccomplete_script: Script to call complete with, if not the executable to complete.
        If supplied, will be used to complete *all* passed executables.
    :type jaccomplete_script: str or None
    """

    if complete_arguments is None:
        complete_options = "-o nospace -o default -o bashdefault" if use_defaults else "-o nospace -o bashdefault"
    else:
        complete_options = " ".join(complete_arguments)

    if shell == "bash" or shell == "zsh":
        quoted_executables = [quote(i) for i in executables]
        executables_list = " ".join(quoted_executables)
        script = jaccomplete_script
        if script:
            # If the script path contain a space, this would generate an invalid function name.
            function_suffix = "_" + script.replace(" ", "_SPACE_")
        else:
            script = ""
            function_suffix = ""
        code = bashcode % dict(
            complete_opts=complete_options,
            executables=executables_list,
            jaccomplete_script=script,
            function_suffix=function_suffix,
        )
    elif shell == "fish":
        code = ""
        for executable in executables:
            script = jaccomplete_script or executable
            completion_arg = "--path" if "/" in executable else "--command"  # use path for absolute paths
            function_name = executable.replace("/", "_")  # / not allowed in function name

            code += fishcode % dict(
                executable=executable,
                jaccomplete_script=script,
                completion_arg=completion_arg,
                function_name=function_name,
            )
    elif shell == "powershell":
        code = ""
        for executable in executables:
            script = jaccomplete_script or executable
            code += powershell_code % dict(executable=executable, jaccomplete_script=script)

    else:
        code = ""
        for executable in executables:
            script = jaccomplete_script
            # If no script was specified, default to the executable being completed.
            if not script:
                script = executable
            code += shell_codes.get(shell, "") % dict(executable=executable, jaccomplete_script=script)

    return code

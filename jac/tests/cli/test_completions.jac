"""Shell activation tests for generated completion scripts."""

import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from unittest { SkipTest }
import from unittest.mock { patch }
import from jaclang.cli.jaccomplete { static_shellcode }
import from jaclang.cli.commands.tools { _install_completion }

def run_zsh(script: str, directory: str) -> str {
    shell = shutil.which("zsh");
    if not shell {
        raise SkipTest("zsh is required for shell activation tests");
    }
    result = subprocess.run(
        [shell, "-f", "-c", script, "probe", directory],
        capture_output=True,
        text=True,
        timeout=15
    );
    assert result.returncode == 0 , result.stderr;
    assert result.stderr == "" , result.stderr;
    return result.stdout;
}

test "sourcing zsh completions registers the chosen executable" {
    with tempfile.TemporaryDirectory() as directory {
        for exe in ["jac", "probejac"] {
            (Path(directory) / "completion.zsh").write_text(
                static_shellcode([], executable=exe, shell="zsh")
            );
            output = run_zsh(
                "autoload -Uz compinit\ncompinit -D\n"
                'source "$1/completion.zsh"\n'
                'print -r -- "${_comps['
                    + exe
                    + ']-MISSING}"\n',
                directory
            );
            assert output == "_" + exe + "\n";
        }
    }
}

test "zsh autoload still invokes the generated handler" {
    with tempfile.TemporaryDirectory() as directory {
        (Path(directory) / "_jac").write_text(static_shellcode([], shell="zsh"));
        output = run_zsh(
            'fpath=("$1" $fpath)\n'
            "autoload -Uz compinit\ncompinit -D\n"
            'print -r -- "${_comps[jac]-MISSING}"\n'
            # Observe dispatch without requiring an interactive ZLE session.
            '_arguments() { print -r -- "handler called"; }\n'
            "_jac\n",
            directory
        );
        assert output == "_jac\nhandler called\n";
    }
}

test "installed zsh startup block activates and remains unique" {
    with tempfile.TemporaryDirectory() as directory {
        config = Path(directory) / ".zshrc";
        config.write_text("autoload -Uz compinit\ncompinit -D\n");
        code = static_shellcode([], shell="zsh");
        with patch("os.path.expanduser", return_value=directory) {
            assert _install_completion("zsh", code) == 0;
            assert _install_completion("zsh", code) == 0;
        }
        assert config.read_text().count("# >>> jac completion >>>") == 1;
        output = run_zsh(
            'source "$1/.zshrc"\n' 'print -r -- "${_comps[jac]-MISSING}"\n', directory
        );
        assert output == "_jac\n";
    }
}

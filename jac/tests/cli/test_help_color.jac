"""Color-scheme tests for the top-level manifest help screens.

The hand-rolled `jac` / `jac --help` screens are colorized to match the theme
Python 3.14's argparse applies to `jac COMMAND --help`, so the two help
surfaces read as one system. Coloring is gated through `JacConsole.use_color`
(NO_COLOR / TERM=dumb / stdout.isatty()); these tests pin that contract:

  1. When color is enabled, section headers, command names, and the program
     name are wrapped in the expected ANSI roles.
  2. When color is disabled, the output is byte-for-byte plain text — no ANSI.
  3. Coloring never changes layout: stripping the ANSI from the colored output
     reproduces the plain output exactly (padding is computed on raw lengths,
     so columns stay aligned).
"""

import io;
import re;
import from contextlib { redirect_stdout }
import from jaclang.cli.console { _get_console }
import from jaclang.cli.command { CommandSpec }
import from jaclang.cli.manifest { iter_command_meta }
import from jaclang.cli.manifest_help { format_curated_help, format_verbose_help }
import from jaclang.cli.manifest_route { handle_manifest_route }


# ANSI roles the formatter uses (mirrors argparse's 3.14 theme).
glob _HEADER: str = "\033[1;34m",  # bold blue  -> section/group headers
     _CMD: str = "\033[32m",  # green      -> command names
     _PROG: str = "\033[1;35m";  # bold magenta -> program name


def _sample_commands -> list[CommandSpec] {
    return [
        CommandSpec(
            name="run",
            help="Run a Jac program",
            group="execution",
            tier="core",
            hidden=False,
            handler_module="jaclang.cli.commands.execution",
            handler_name="run"
        ),
        CommandSpec(
            name="check",
            help="Type check Jac files",
            group="analysis",
            tier="core",
            hidden=False,
            handler_module="jaclang.cli.commands.analysis",
            handler_name="check"
        )
    ];
}


def _strip_ansi(s: str) -> str {
    return re.sub("\033\\[[0-9;]*m", "", s);
}


"""Render `fn()` with the live console's `use_color` forced on/off, restored after."""
def _with_color(enabled: bool, fn: any) -> str {
    c = _get_console();
    saved = c.use_color;
    c.use_color = enabled;
    try {
        return fn();
    } finally {
        c.use_color = saved;
    }
}


test "main help applies the argparse-matching palette when color is enabled" {
    out = _with_color(True, lambda { format_verbose_help(prog="jac"); });
    assert _HEADER in out , f"section headers not colored bold-blue; captured={out!r}";
    assert _CMD in out , f"command names not colored green; captured={out!r}";
    assert _PROG in out , f"program name not colored magenta; captured={out!r}";
}


test "main help is plain text when color is disabled" {
    out = _with_color(False, lambda { format_verbose_help(prog="jac"); });
    assert "\033[" not in out , f"disabled color still emitted ANSI escapes; captured={out!r}";
    assert "Program Execution:" in out , f"header text missing; captured={out!r}";
    assert "run" in out and "check" in out , f"command names missing; captured={out!r}";
}


test "main help coloring preserves layout (strip-ANSI == plain)" {
    on = _with_color(True, lambda { format_verbose_help(prog="jac"); });
    off = _with_color(False, lambda { format_verbose_help(prog="jac"); });
    assert _strip_ansi(on) == off , f"coloring changed layout; stripped={_strip_ansi(
        on
    )!r} plain={off!r}";
}


test "curated (bare jac) help colors headers/commands/prog and stays plain when off" {
    on = _with_color(True, lambda { format_curated_help(prog="jac"); });
    off = _with_color(False, lambda { format_curated_help(prog="jac"); });

    assert _HEADER in on , f"curated headers not colored; captured={on!r}";
    assert _CMD in on , f"curated command names not colored; captured={on!r}";
    assert _PROG in on , f"curated program name not colored; captured={on!r}";
    assert "\033[" not in off , f"curated help emitted ANSI when color disabled; captured={off!r}";
    assert _strip_ansi(on) == off , f"curated coloring changed layout; stripped={_strip_ansi(
        on
    )!r} plain={off!r}";
}


def _hidden_names -> list[str] {
    return sorted(
        [
            m.name
            for m in iter_command_meta(include_hidden=True)
            if m.hidden
        ]
    );
}


def _route_output(argv: list[str]) -> str {
    buf = io.StringIO();
    with redirect_stdout(buf) {
        _with_color(False, lambda { handle_manifest_route(argv); });
    }
    return buf.getvalue();
}


test "main help lists hidden commands only when asked" {
    hidden = _hidden_names();
    assert hidden , "expected at least one hidden command in the manifest";
    plain = _with_color(False, lambda { format_verbose_help(prog="jac"); });
    full = _with_color(
        False, lambda { format_verbose_help(prog="jac", include_hidden=True); }
    );
    assert "Hidden:" not in plain , f"default help shows a Hidden section; captured={plain!r}";
    assert "Hidden:" in full , f"--all help has no Hidden section; captured={full!r}";
    for name in hidden {
        assert f"    {name} " not in plain , f"hidden command {name!r} leaked into default help";
        assert f"    {name} " in full , f"hidden command {name!r} missing from --all help";
    }
}


test "jac --help --all routes to the full listing in either order" {
    hidden = _hidden_names();
    for argv in (['--help', '--all'], ['--all', '--help'], ['-h', '--all']) {
        out = _route_output(argv);
        assert "Hidden:" in out , f"{argv} did not list hidden commands; captured={out!r}";
        for name in hidden {
            assert f"    {name} " in out , f"{argv} omitted hidden command {name!r}";
        }
    }
    assert "Hidden:" not in _route_output(['--help']) , "plain --help listed hidden commands";
}

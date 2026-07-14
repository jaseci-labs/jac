"""Color-scheme tests for the top-level `HelpFormatter`.

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

import re;
import from jaclang.cli.help { HelpFormatter }
import from jaclang.cli.command { CommandSpec }
import from jaclang.cli.console { _get_console }


# ANSI roles the formatter uses (mirrors argparse's 3.14 theme).
glob _HEADER: str = "\033[1;34m",  # bold blue  -> section/group headers
     _CMD: str = "\033[32m",  # green      -> command names
     _PROG: str = "\033[1;35m";  # bold magenta -> program name


def _specs -> list[CommandSpec] {
    return [
        CommandSpec(
            name="run", help="Run a Jac program", group="execution", tier="core"
        ),
        CommandSpec(
            name="check", help="Type check Jac files", group="analysis", tier="core"
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
    fmt = HelpFormatter();
    out = _with_color(
        True,
        lambda { fmt.format_main_help(
            _specs(), prog="jac", version="9.9.9", verbose=True
        ); }
    );
    assert _HEADER in out , f"section headers not colored bold-blue; captured={out!r}";
    assert _CMD in out , f"command names not colored green; captured={out!r}";
    assert _PROG in out , f"program name not colored magenta; captured={out!r}";
}


test "main help is plain text when color is disabled" {
    fmt = HelpFormatter();
    out = _with_color(
        False,
        lambda { fmt.format_main_help(
            _specs(), prog="jac", version="9.9.9", verbose=True
        ); }
    );
    assert "\033[" not in out , f"disabled color still emitted ANSI escapes; captured={out!r}";
    # Data still present, just uncolored.
    assert "Program Execution:" in out , f"header text missing; captured={out!r}";
    assert "run" in out and "check" in out , f"command names missing; captured={out!r}";
}


test "main help coloring preserves layout (strip-ANSI == plain)" {
    fmt = HelpFormatter();
    on = _with_color(
        True,
        lambda { fmt.format_main_help(
            _specs(), prog="jac", version="9.9.9", verbose=True
        ); }
    );
    off = _with_color(
        False,
        lambda { fmt.format_main_help(
            _specs(), prog="jac", version="9.9.9", verbose=True
        ); }
    );
    assert _strip_ansi(on) == off , f"coloring changed layout; stripped={_strip_ansi(
        on
    )!r} plain={off!r}";
}


test "curated (bare jac) help colors headers/commands/prog and stays plain when off" {
    fmt = HelpFormatter();
    on = _with_color(True, lambda { fmt.format_curated_help(_specs(), prog="jac"); });
    off = _with_color(False, lambda { fmt.format_curated_help(_specs(), prog="jac"); });

    assert _HEADER in on , f"curated headers not colored; captured={on!r}";
    assert _CMD in on , f"curated command names not colored; captured={on!r}";
    assert _PROG in on , f"curated program name not colored; captured={on!r}";
    assert "\033[" not in off , f"curated help emitted ANSI when color disabled; captured={off!r}";
    assert _strip_ansi(on) == off , f"curated coloring changed layout; stripped={_strip_ansi(
        on
    )!r} plain={off!r}";
}

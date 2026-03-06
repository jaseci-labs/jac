"""Test jacpretty CLI design library"""

import io;
import os;
import from jaclang.cli.jacpretty { Style, Console, render_markup, _parse_color }

# Helper to create test console
def make_console(
    no_color: bool = False, width: int = 80
) -> tuple[Console, io.StringIO] {
    buf = io.StringIO();
    console = Console(file=buf, force_terminal=True, no_color=no_color, width=width);
    return (console, buf);
}

test "basic styles produce correct ANSI codes" {
    assert Style("bold").render("Text") == "\x1b[1mText\x1b[0m";
    assert Style("red").render("Error") == "\x1b[31mError\x1b[0m";
    assert Style("bold red").render("Alert") == "\x1b[1;31mAlert\x1b[0m";
    assert Style("green on blue").render("BG") == "\x1b[32;44mBG\x1b[0m";
}

test "all color formats work" {
    assert "\x1b[31m" in Style("red").render("X");
    assert Style("#ff5733").render("X") == "\x1b[38;2;255;87;51mX\x1b[0m";
    assert Style("rgb(128,64,200)").render("X") == "\x1b[38;2;128;64;200mX\x1b[0m";
    assert Style("color(196)").render("X") == "\x1b[38;5;196mX\x1b[0m";
}

test "markup renders correctly for common use cases" {
    assert render_markup("[red]Error[/]") == "\x1b[31mError\x1b[0m";
    assert render_markup("[bold red]Warning[/]") == "\x1b[1;31mWarning\x1b[0m";
    output = render_markup("[bold]Bold [red]and red[/][/]");
    assert "\x1b[1m" in output and "\x1b[1;31m" in output;
    output = render_markup("[red]Error[/] and [green]Success[/]");
    assert "\x1b[31mError\x1b[0m" in output and "\x1b[32mSuccess\x1b[0m" in output;
    assert "[bold]" in render_markup("Use \\[bold\\] for bold");
}

test "NO_COLOR mode strips all ANSI codes" {
    (console, buf) = make_console(no_color=True);
    console.print("[bold red]Test[/]");
    output = buf.getvalue();
    assert "\x1b[" not in output;
    assert "Test" in output;
}

test "NO_COLOR environment variable works" {
    original = os.environ.get("NO_COLOR");
    os.environ["NO_COLOR"] = "1";
    try {
        buf = io.StringIO();
        console = Console(file=buf, force_terminal=True);
        console.print("[red]Test[/]");
        assert "\x1b[" not in buf.getvalue();
    } finally {
        if original is None {
            os.environ.pop("NO_COLOR", None);
        } else {
            os.environ["NO_COLOR"] = original;
        }
    }
}

test "console print handles markup and styles" {
    (console, buf) = make_console();
    console.print("[green]Success:[/] Done");
    assert "\x1b[32m" in buf.getvalue() and "Success:" in buf.getvalue();
    buf.truncate(0);
    buf.seek(0);
    console.print("Error", style="bold red");
    assert "\x1b[1;31m" in buf.getvalue();
    buf.truncate(0);
    buf.seek(0);
    console.print("A", "B", "C", sep="|");
    assert "A|B|C" in buf.getvalue();
}

test "console rule renders correctly" {
    (console, buf) = make_console(width=50);
    console.rule("Section");
    output = buf.getvalue();
    assert "Section" in output and "─" in output;
    buf.truncate(0);
    buf.seek(0);
    console.rule();
    assert buf.getvalue().count("─") == 50;
}

test "edge cases dont crash" {
    # Empty styles
    assert Style("").render("Text") == "Text";

    # Unknown colors (should ignore)
    output = Style("unknowncolor bold").render("Text");
    assert "Text" in output;

    # Malformed colors (should ignore)
    assert "Text" in Style("#fff").render("Text");
    assert "Text" in Style("rgb(255,0)").render("Text");

    # Unicode
    assert "✓" in Style("green").render("✓ Success");
}

test "color parsing works for all formats" {
    assert _parse_color("red") == ("31", );
    assert _parse_color("red", bg=True) == ("41", );
    assert _parse_color("bright_red") == ("91", );
    assert _parse_color("#ff0000") == ("38", "2", "255", "0", "0");
    assert _parse_color("rgb(255, 128, 0)") == ("38", "2", "255", "128", "0");
    assert _parse_color("color(196)") == ("38", "5", "196");
    assert _parse_color("invalid") is None;
}

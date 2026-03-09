"""Test jacpretty CLI design library"""

import io;
import os;
import from jaclang.cli.jacpretty { Style, Console, Theme, Panel, Table, render_markup, _parse_color }

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

# Theme
test "theme get and fallback" {
    theme = Theme({'success': 'green', 'error': 'red'});
    assert theme.get('success') == 'green';
    assert theme.get('missing') == '';
    assert theme.get('missing', 'dim') == 'dim';
}

test "console resolves theme style names" {
    theme = Theme({'hi': 'bold cyan'});
    (console, buf) = make_console();
    console = Console(file=buf, force_terminal=True, theme=theme);
    console.print("text", style='hi');
    assert '\x1b[1;36m' in buf.getvalue();
}

# Panel
test "panel renders border, title and content" {
    panel = Panel("Hello", title="Test", padding=(0, 0));
    output = panel.render(30);
    lines = output.split('\n');
    assert len(lines) == 3;
    assert "Hello" in output and "Test" in output and "─" in output;
}

test "panel border_style adds markup to render output" {
    panel = Panel("Hi", border_style="red", padding=(0, 0));
    output = panel.render(20);
    assert "red" in output;
}

test "panel padding adds extra lines" {
    panel = Panel("x", padding=(1, 0));
    lines = panel.render(20).split('\n');
    assert len(lines) >= 5;  # top + pad + content + pad + bottom
}

# Table
test "table renders headers, separator and rows" {
    table = Table(show_header=True, header_style="bold");
    table.add_column("Name");
    table.add_row("foo");
    output = table.render(40);
    assert "Name" in output and "foo" in output and "─" in output;
}

test "table renders title and column style" {
    table = Table(title="Results", show_header=False, header_style="");
    table.add_column("X", style="green");
    table.add_row("val");
    output = table.render(40);
    assert "Results" in output and "[green]" in output;
}

test "empty table returns empty string" {
    assert Table().render(80) == "";
}

# Spinner / status
test "status non-terminal prints text and works as context manager" {
    buf = io.StringIO();
    console = Console(file=buf, force_terminal=False);
    entered = False;
    with console.status("Loading...") {
        entered = True;
    }
    assert entered and "Loading..." in buf.getvalue();
}

test "status terminal mode spinner runs without error" {
    buf = io.StringIO();
    with Console(file=buf, force_terminal=True).status("Working") {
        assert True;
    }
}

# Console.log
test "console log includes message" {
    (console, buf) = make_console();
    console.log("Hello");
    assert "Hello" in buf.getvalue();
}

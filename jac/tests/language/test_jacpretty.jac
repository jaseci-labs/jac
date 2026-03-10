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

test "hex color parsing handles invalid characters gracefully" {
    # These patterns caused ValueError crashes before the fix
    # Pattern: #XXXX followed by non-hex chars totaling 7 chars
    assert _parse_color('#2000"}') is None;
    assert _parse_color('#2000",') is None;
    assert _parse_color('#xx2"xx') is None;
    assert _parse_color("#2\"xxxx") is None;

    # Valid hex colors still work
    assert _parse_color("#ff00aa") == ("38", "2", "255", "0", "170");
    assert _parse_color("#000000") == ("38", "2", "0", "0", "0");
}

test "rgb color parsing validates numeric values" {
    # Invalid non-numeric values should return None
    assert _parse_color("rgb(abc, def, ghi)") is None;
    assert _parse_color("rgb(1, two, 3)") is None;
    assert _parse_color("rgb(, , )") is None;

    # Valid rgb still works
    assert _parse_color("rgb(0, 0, 0)") == ("38", "2", "0", "0", "0");
    assert _parse_color("rgb(255, 255, 255)") == ("38", "2", "255", "255", "255");
}

test "color index parsing validates numeric values" {
    # Invalid non-numeric values should return None
    assert _parse_color("color(abc)") is None;
    assert _parse_color("color(not-a-number)") is None;
    assert _parse_color("color()") is None;

    # Valid color indices still work
    assert _parse_color("color(0)") == ("38", "5", "0");
    assert _parse_color("color(255)") == ("38", "5", "255");
}

test "render_markup preserves null bytes in input" {
    # Null bytes should not be corrupted to brackets
    input_with_nulls = "text\x00with\x01nulls";
    result = render_markup(input_with_nulls);
    assert result == input_with_nulls;
}

test "console width zero is respected" {
    buf = io.StringIO();
    console = Console(file=buf, width=0);
    assert console.width == 0;
}

test "render_markup handles JSON-like content without crashing" {
    import json;
    # Real-world crash case: JSON with hex-like patterns
    test_cases = [
        {"rows_json": json.dumps([{"addr": "Suite #2000"}])},
        {"rows_json": json.dumps([{"addr": "Suite #2000", "city": "NYC"}])},
        {"rows_json": json.dumps([{"addr": f"Unit #{i}000"} for i in range(5)])},

    ];
    for case in test_cases {
        # Should not raise ValueError
        result = render_markup(str(case));
        assert result is not None;
    }
}

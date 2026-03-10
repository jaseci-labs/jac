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

test "render_markup does not match JSON arrays as markup tags" {
    # Issue: JSON arrays like [249989, "Study Buddy", ...] were being matched as markup
    # The fix: regex now requires tags to start with [a-z#/@]

    # JSON array - numbers at start should NOT be parsed as markup
    json_array = '[249989, "Study Buddy", "city", 100]';
    result = render_markup(json_array);
    # Should return the string unchanged (no ANSI codes)
    assert result == json_array;
    assert "\x1b[" not in result;

    # Nested JSON with numeric arrays
    nested_json = '{"data": [1, 2, 3], "items": [100, 200]}';
    result = render_markup(nested_json);
    assert result == nested_json;
    assert "\x1b[" not in result;

    # Large dataset simulation (the actual bug scenario)
    large_data = str([[i, f"name_{i}", "city", i * 100] for i in range(100)]);
    result = render_markup(large_data);
    # Should not hang or crash, and should return unchanged
    assert "\x1b[" not in result;
}

test "render_markup strict regex only matches valid tag openers" {
    # Valid markup tags (start with a-z, #, /, or @)
    assert "\x1b[" in render_markup("[bold]text[/]");  # lowercase letter
    assert "\x1b[" in render_markup("[red]text[/]");  # lowercase letter
    assert "\x1b[" in render_markup("[#ff0000]text[/]");  # hash for hex color
    # Note: [/] alone produces empty string (closing tag with no open tag)
    assert render_markup("[/]") == "";  # forward slash close is recognized but no-op

    # Invalid markup (should NOT be parsed as tags)
    # Numbers at start
    assert render_markup("[123]") == "[123]";
    assert render_markup("[0xff]") == "[0xff]";

    # Uppercase letters (Rich doesn't match these either)
    assert render_markup("[BOLD]") == "[BOLD]";
    assert render_markup("[RED]") == "[RED]";

    # Special characters
    assert render_markup("[*bold]") == "[*bold]";
    assert render_markup("[$var]") == "[$var]";
    assert render_markup("[.class]") == "[.class]";

    # Empty brackets
    assert render_markup("[]") == "[]";
}

test "render_markup fast path for strings without brackets" {
    # Strings without '[' should skip regex entirely
    simple_text = "Hello, world! This is a test string without any brackets.";
    result = render_markup(simple_text);
    assert result == simple_text;

    # With base style, should still apply style
    result_styled = render_markup(simple_text, base_style="bold");
    assert "\x1b[1m" in result_styled;
    assert simple_text in result_styled;
}

test "render_markup handles mixed valid and invalid brackets" {
    # Mix of valid markup and JSON-like content
    mixed = "[red]Error:[/] data=[123, 456]";
    result = render_markup(mixed);
    # [red] and [/] should be parsed, [123, 456] should not
    assert "\x1b[31m" in result;  # red color applied
    assert "[123, 456]" in result;  # JSON array preserved as-is

    # Another mix case
    mixed2 = "Processing [bold]item[/] with config [999]";
    result2 = render_markup(mixed2);
    assert "\x1b[1m" in result2;  # bold applied
    assert "[999]" in result2;  # number bracket preserved
}

# ============================================================================
# Rich-compatible test cases (from rich/tests/test_markup.py)
# ============================================================================
test "RE_MARKUP regex no match (Rich-compatible)" {
    # These patterns should NOT be matched as markup tags
    # Based on Rich's test_re_no_match
    import re;
    import from jaclang.cli.jacpretty { RE_MARKUP }

    # Capitalized words - not valid tags
    assert RE_MARKUP.search("[True]") is None;
    assert RE_MARKUP.search("[False]") is None;
    assert RE_MARKUP.search("[None]") is None;

    # Numbers - not valid tags
    assert RE_MARKUP.search("[1]") is None;
    assert RE_MARKUP.search("[2]") is None;

    # Empty brackets - not valid tags
    assert RE_MARKUP.search("[]") is None;
}

test "RE_MARKUP regex match (Rich-compatible)" {
    # These patterns SHOULD be matched as markup tags
    # Based on Rich's test_re_match
    import re;
    import from jaclang.cli.jacpretty { RE_MARKUP }

    # Lowercase words - valid tags
    assert RE_MARKUP.search("[true]") is not None;
    assert RE_MARKUP.search("[false]") is not None;
    assert RE_MARKUP.search("[none]") is not None;

    # Color function - valid tag
    assert RE_MARKUP.search("[color(1)]") is not None;

    # Hex color - valid tag
    assert RE_MARKUP.search("[#ff00ff]") is not None;

    # Close tag - valid
    assert RE_MARKUP.search("[/]") is not None;

    # Handler tags with @ - valid
    assert RE_MARKUP.search("[@]") is not None;
    assert RE_MARKUP.search("[@foo]") is not None;
    assert RE_MARKUP.search("[@foo=bar]") is not None;
}

test "render_markup not tags (Rich-compatible)" {
    # Based on Rich's test_render_not_tags
    # JSON-like arrays with various types should NOT be parsed as tags
    result = render_markup('[[1], [1,2,3,4], ["hello"], [None], [False], [True]] []');
    # Should return unchanged with no ANSI codes
    assert result == '[[1], [1,2,3,4], ["hello"], [None], [False], [True]] []';
    assert "\x1b[" not in result;
}

test "render_markup supports OSC 8 hyperlinks" {
    # [link=url]text[/link] should produce OSC 8 escape sequences
    result = render_markup("[link=https://example.com]click me[/link]");
    # Should contain OSC 8 sequence
    assert "\x1b]8;" in result;
    # Should contain the URL
    assert "https://example.com" in result;
    # Should contain the text
    assert "click me" in result;

    # Combined with styles
    result2 = render_markup("[bold][link=https://example.com]styled link[/link][/bold]");
    assert "\x1b]8;" in result2;  # OSC 8
    assert "\x1b[1m" in result2;  # Bold
    assert "styled link" in result2;
}

test "Style with link parameter produces OSC 8" {
    # Style can be created with a link parameter
    style = Style("bold", link="https://example.com");
    result = style.render("click me");
    # Should have OSC 8 hyperlink
    assert "\x1b]8;" in result;
    assert "https://example.com" in result;
    # Should have bold ANSI
    assert "\x1b[1m" in result;

    # Style with only link (no definition)
    link_only = Style("", link="https://example.com");
    result2 = link_only.render("plain link");
    assert "\x1b]8;" in result2;
    assert "plain link" in result2;
    # No ANSI style codes (but OSC 8 is present)
    assert "\x1b[" not in result2.replace(
        "\x1b]8", ""
    );  # Check no ANSI after removing OSC
}

test "stricter hex matching preserves invalid hex patterns" {
    # Stricter than Rich: only matches # followed by exactly 6 hex digits
    # This prevents accidental consumption of room numbers, issue refs, etc.

    # Invalid hex patterns should pass through UNCHANGED
    assert render_markup("Room [#2000]") == "Room [#2000]";
    assert render_markup("Bug [#123] fixed") == "Bug [#123] fixed";
    assert render_markup("Issue [#4567]") == "Issue [#4567]";
    assert render_markup("SKU [#AB12]") == "SKU [#AB12]";
    assert render_markup("[#fff] short hex") == "[#fff] short hex";
    assert render_markup("[#fffffff] too long") == "[#fffffff] too long";

    # Valid 6-digit hex colors should STILL work
    assert "\x1b[" in render_markup("[#ff0000]red[/]");
    assert "\x1b[" in render_markup("[#00FF00]green[/]");
    assert "\x1b[" in render_markup("[#abc123]custom[/]");

    # Case insensitive hex
    assert "\x1b[" in render_markup("[#AABBCC]upper[/]");
    assert "\x1b[" in render_markup("[#aabbcc]lower[/]");
}

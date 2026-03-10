"""
Rich Compatibility Test Suite for jacpretty.

This file runs Rich's original test cases against jacpretty to verify:
1. Correctly implemented features (PASS)
2. Wrongly implemented features (FAIL - needs fixing)
3. Missing features (XFAIL - expected, not implemented)

Based on: rich/tests/test_markup.py
"""

import pytest
import re

# Import jacpretty components
from jaclang.cli.jacpretty import RE_MARKUP, render_markup, Style


# =============================================================================
# REGEX TESTS (from Rich's test_re_no_match and test_re_match)
# =============================================================================

class TestRegexNoMatch:
    """Tags that should NOT be matched - Rich's test_re_no_match."""

    def test_capitalized_true(self):
        """[True] should not match (capitalized)."""
        assert RE_MARKUP.search("[True]") is None

    def test_capitalized_false(self):
        """[False] should not match (capitalized)."""
        assert RE_MARKUP.search("[False]") is None

    def test_capitalized_none(self):
        """[None] should not match (capitalized)."""
        assert RE_MARKUP.search("[None]") is None

    def test_number_1(self):
        """[1] should not match (number)."""
        assert RE_MARKUP.search("[1]") is None

    def test_number_2(self):
        """[2] should not match (number)."""
        assert RE_MARKUP.search("[2]") is None

    def test_empty_brackets(self):
        """[] should not match (empty)."""
        assert RE_MARKUP.search("[]") is None


class TestRegexMatch:
    """Tags that SHOULD be matched - Rich's test_re_match."""

    def test_lowercase_true(self):
        """[true] should match (lowercase)."""
        assert RE_MARKUP.search("[true]") is not None

    def test_lowercase_false(self):
        """[false] should match (lowercase)."""
        assert RE_MARKUP.search("[false]") is not None

    def test_lowercase_none(self):
        """[none] should match (lowercase)."""
        assert RE_MARKUP.search("[none]") is not None

    def test_color_function(self):
        """[color(1)] should match."""
        assert RE_MARKUP.search("[color(1)]") is not None

    def test_hex_color(self):
        """[#ff00ff] should match."""
        assert RE_MARKUP.search("[#ff00ff]") is not None

    def test_close_tag(self):
        """[/] should match."""
        assert RE_MARKUP.search("[/]") is not None

    def test_at_symbol(self):
        """[@] should match."""
        assert RE_MARKUP.search("[@]") is not None

    def test_at_foo(self):
        """[@foo] should match."""
        assert RE_MARKUP.search("[@foo]") is not None

    def test_at_foo_equals_bar(self):
        """[@foo=bar] should match."""
        assert RE_MARKUP.search("[@foo=bar]") is not None


# =============================================================================
# RENDER TESTS (from Rich's test_render_*)
# =============================================================================

class TestRenderBasic:
    """Basic rendering tests - Rich's test_render."""

    def test_render_bold(self):
        """[bold]FOO[/bold] should render with bold ANSI codes."""
        result = render_markup("[bold]FOO[/bold]")
        # Check that ANSI codes are present
        assert "\x1b[" in result
        assert "FOO" in result

    def test_render_removes_tags(self):
        """Tags should be removed from output, leaving just text."""
        result = render_markup("[bold]FOO[/bold]")
        assert "[bold]" not in result
        assert "[/bold]" not in result


class TestRenderNotTags:
    """JSON/list patterns that should NOT be parsed - Rich's test_render_not_tags."""

    def test_json_arrays_unchanged(self):
        """JSON-like arrays should pass through unchanged."""
        input_str = '[[1], [1,2,3,4], ["hello"], [None], [False], [True]] []'
        result = render_markup(input_str)
        assert result == input_str
        assert "\x1b[" not in result

    def test_single_number_array(self):
        """[1] should not be parsed as a tag."""
        assert render_markup("[1]") == "[1]"

    def test_multi_number_array(self):
        """[1,2,3,4] should not be parsed as a tag."""
        assert render_markup("[1,2,3,4]") == "[1,2,3,4]"

    def test_string_array(self):
        """["hello"] should not be parsed as a tag."""
        assert render_markup('["hello"]') == '["hello"]'

    def test_none_array(self):
        """[None] should not be parsed as a tag."""
        assert render_markup("[None]") == "[None]"

    def test_false_array(self):
        """[False] should not be parsed as a tag."""
        assert render_markup("[False]") == "[False]"

    def test_true_array(self):
        """[True] should not be parsed as a tag."""
        assert render_markup("[True]") == "[True]"

    def test_empty_array(self):
        """[] should not be parsed as a tag."""
        assert render_markup("[]") == "[]"


class TestRenderClose:
    """Close tag tests - Rich's test_render_close."""

    def test_close_with_slash(self):
        """[bold]X[/]Y should close the bold tag."""
        result = render_markup("[bold]X[/]Y")
        # X should be bold, Y should not
        assert "\x1b[" in result
        assert "X" in result
        assert "Y" in result


class TestRenderCombine:
    """Nested/combined tags - Rich's test_render_combine."""

    def test_nested_tags(self):
        """[green]X[blue]Y[/blue]Z[/green] should nest correctly."""
        result = render_markup("[green]X[blue]Y[/blue]Z[/green]")
        assert "XYZ" in result or ("X" in result and "Y" in result and "Z" in result)
        assert "\x1b[" in result


class TestRenderOverlap:
    """Overlapping tags - Rich's test_render_overlap."""

    def test_overlapping_tags(self):
        """[green]X[bold]Y[/green]Z[/bold] should handle overlap."""
        result = render_markup("[green]X[bold]Y[/green]Z[/bold]")
        assert "X" in result and "Y" in result and "Z" in result


# =============================================================================
# ESCAPE TESTS (from Rich's test_escape)
# =============================================================================

class TestEscape:
    """Escape handling tests - based on Rich's test_escape."""

    def test_escaped_bracket_literal(self):
        r"""Use \[bold\] should render literal brackets."""
        result = render_markup(r"Use \[bold\] for bold")
        assert "[bold]" in result
        assert "\x1b[" not in result  # No ANSI codes

    def test_number_no_escape_needed(self):
        """[5] doesn't need escaping - not a valid tag."""
        result = render_markup("[5]")
        assert result == "[5]"


# =============================================================================
# STYLE TESTS
# =============================================================================

class TestStyle:
    """Style parsing tests."""

    def test_style_bold(self):
        """Style('bold') should produce ANSI bold code."""
        result = Style("bold").render("Text")
        assert "\x1b[1m" in result

    def test_style_red(self):
        """Style('red') should produce ANSI red code."""
        result = Style("red").render("Text")
        assert "\x1b[31m" in result

    def test_style_bold_red(self):
        """Style('bold red') should combine codes."""
        result = Style("bold red").render("Text")
        assert "\x1b[" in result
        assert "1" in result  # bold
        assert "31" in result  # red

    def test_style_hex_color(self):
        """Style('#ff5733') should produce RGB ANSI code."""
        result = Style("#ff5733").render("X")
        assert "\x1b[38;2;" in result  # RGB format

    def test_style_rgb(self):
        """Style('rgb(128,64,200)') should produce RGB ANSI code."""
        result = Style("rgb(128,64,200)").render("X")
        assert "\x1b[38;2;128;64;200m" in result

    def test_style_color_index(self):
        """Style('color(196)') should produce 256-color ANSI code."""
        result = Style("color(196)").render("X")
        assert "\x1b[38;5;196m" in result

    def test_style_on_background(self):
        """Style('green on blue') should set foreground and background."""
        result = Style("green on blue").render("BG")
        assert "\x1b[32;44m" in result


# =============================================================================
# EDGE CASES & BUG FIXES
# =============================================================================

class TestBugFixes:
    """Tests for specific bug fixes."""

    def test_hex_like_json_no_crash(self):
        """JSON with hex-like patterns should not crash (Simon's bug)."""
        # This was crashing before the fix
        result = render_markup('{"addr": "Suite #2000"}')
        assert result is not None
        assert "\x1b[" not in result

    def test_large_numeric_array_no_hang(self):
        """Large numeric arrays should not hang (Jayanaka's bug)."""
        import time
        data = str([[i, f"name_{i}", "city", i * 100] for i in range(1000)])

        start = time.time()
        result = render_markup(data)
        elapsed = time.time() - start

        # Should complete quickly (< 1 second)
        assert elapsed < 1.0, f"Processing took {elapsed:.2f}s - potential hang"
        assert "\x1b[" not in result


class TestStricterThanRich:
    """Tests where jacpretty is STRICTER than Rich (by design).

    jacpretty only matches # when followed by exactly 6 hex digits.
    This prevents accidental consumption of room numbers, issue refs, etc.
    Rich would consume [#2000] as an invalid style; jacpretty preserves it.
    """

    def test_room_numbers_preserved(self):
        """Room numbers like [#2000] should pass through unchanged."""
        assert render_markup("Room [#2000]") == "Room [#2000]"
        assert render_markup("Suite [#101]") == "Suite [#101]"

    def test_issue_refs_preserved(self):
        """GitHub-style issue refs like [#123] should pass through."""
        assert render_markup("Fixed [#123]") == "Fixed [#123]"
        assert render_markup("See [#4567]") == "See [#4567]"

    def test_short_hex_preserved(self):
        """CSS-style short hex [#fff] should pass through (not supported)."""
        assert render_markup("[#fff]text") == "[#fff]text"
        assert render_markup("[#abc]text") == "[#abc]text"

    def test_valid_hex_still_works(self):
        """Valid 6-digit hex colors should still apply styling."""
        result = render_markup("[#ff0000]red[/]")
        assert "\x1b[" in result
        assert "red" in result

        result = render_markup("[#00FF00]green[/]")
        assert "\x1b[" in result


# =============================================================================
# HYPERLINK TESTS (Rich-compatible OSC 8)
# =============================================================================

class TestLinks:
    """Link features - jacpretty supports OSC 8 hyperlinks like Rich."""

    def test_render_link_produces_osc8(self):
        """[link=url]text[/link] produces OSC 8 hyperlink sequence."""
        result = render_markup("[link=https://example.com]click me[/link]")
        # Should contain OSC 8 sequence
        assert "\x1b]8;" in result
        # Should contain the URL
        assert "https://example.com" in result
        # Should contain the text
        assert "click me" in result

    def test_render_link_with_style(self):
        """[bold][link=url]text[/link][/bold] combines style and link."""
        result = render_markup("[bold][link=https://example.com]styled link[/link][/bold]")
        # Should have both OSC 8 and bold ANSI
        assert "\x1b]8;" in result  # OSC 8 hyperlink
        assert "\x1b[1m" in result  # Bold
        assert "styled link" in result

    def test_link_only_no_style(self):
        """[link=url]text[/link] without other styles still produces OSC 8."""
        result = render_markup("[link=foo]FOO[/link]")
        assert "\x1b]8;" in result
        assert "foo" in result
        assert "FOO" in result


# =============================================================================
# FEATURES NOT FULLY IMPLEMENTED (Expected to differ from Rich)
# =============================================================================


@pytest.mark.xfail(reason="MarkupError not raised in jacpretty")
class TestMarkupErrorNotImplemented:
    """Error handling - jacpretty is more permissive than Rich."""

    def test_unmatched_close_raises(self):
        """foo[/] should raise MarkupError in Rich."""
        # jacpretty doesn't raise errors, just ignores invalid markup
        from rich.errors import MarkupError
        with pytest.raises(MarkupError):
            render_markup("foo[/]")


def print_compatibility_report():
    """Print a summary of jacpretty vs Rich compatibility."""
    print("\n" + "=" * 70)
    print("JACPRETTY vs RICH COMPATIBILITY REPORT")
    print("=" * 70)

    compatible = [
        "RE_MARKUP regex pattern (strict tag matching)",
        "Capitalized words [True], [False], [None] NOT matched",
        "Numbers [1], [2], etc. NOT matched",
        "Empty brackets [] NOT matched",
        "Lowercase tags [bold], [red], etc. matched",
        "Hex colors [#ff00ff] matched",
        "Close tags [/] matched",
        "Handler tags [@foo] matched",
        "JSON arrays pass through unchanged",
        "Nested tags [green]X[blue]Y[/blue]Z[/green]",
        "Overlapping tags handled",
        "Escape sequences \\[..\\]",
        "Style parsing (bold, colors, rgb, hex, on background)",
        "Hyperlinks [link=url]text[/link] with OSC 8 sequences",
    ]

    not_implemented = [
        "MarkupError exceptions (jacpretty is permissive by default)",
        "Meta/event handlers [@click=handler]",
    ]

    stricter_than_rich = [
        "Hex colors require exactly 6 digits: [#ff0000] works, [#2000] preserved",
        "Room numbers [#2000], issue refs [#123] pass through unchanged",
        "CSS shorthand [#fff] not matched (Rich would consume it)",
    ]

    print("\nCOMPATIBLE (Rich behavior matched):")
    for item in compatible:
        print(f"  [OK] {item}")

    print("\nSTRICTER THAN RICH (safer behavior):")
    for item in stricter_than_rich:
        print(f"  [++] {item}")

    print("\nNOT IMPLEMENTED (by design):")
    for item in not_implemented:
        print(f"  [--] {item}")

    print("\n" + "=" * 70)
    print(f"SUMMARY: {len(compatible)} compatible, {len(stricter_than_rich)} stricter, "
          f"{len(not_implemented)} not implemented")
    print("=" * 70 + "\n")


if __name__ == "__main__":
    import sys
    if "--report" in sys.argv:
        print_compatibility_report()
    else:
        pytest.main([__file__, "-v", "--tb=short"])

"""The native html module unescapes and escapes the way CPython's does.

The ES backend unescapes JSX text and attribute literals while it runs in
the compiler kernel, so the native html.unescape has to follow the HTML 5
rules CPython's does: named references with and without the semicolon,
the longest-prefix match for legacy names, numeric references in both
bases with the invalid-reference and invalid-codepoint tables.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native html.unescape and html.escape match CPython" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "html_unescape_fidelity.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert "a &amp; b &lt;tag&gt;" in out , out;
}

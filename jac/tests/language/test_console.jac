"""Test console output - no ANSI codes in piped/captured output."""

import os;
import subprocess;
import from pathlib { Path }
import jaclang;

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "language", "fixtures"),
     ERR_FILE = os.path.join(
         JAC_ROOT, "tests", "langserve", "fixtures", "circle_pure_err.jac"
     ),
     EDGE_CASES_FILE = os.path.join(FIXTURES, "console_edge_cases.jac"),
     FSTRING_ENCODING_FILE = os.path.join(FIXTURES, "fstring_encoding.jac"),
     ESC = '\x1b[';

"""Run jac and return (stdout, stderr) tuple."""
def run_jac(args: list[str], env_override: dict | None = None) -> tuple[str, str] {
    env = os.environ.copy();
    if env_override {
        env.update(env_override);
    }
    result = subprocess.run(['jac'] + args, capture_output=True, text=True, env=env);
    return (result.stdout, result.stderr);
}

def has_ansi(text: str) -> bool {
    return ESC in text or '[31m' in text or '[0m' in text;
}

# =============================================================================
# Core: isatty() detection - piped output should have no ANSI
# =============================================================================
test "piped stdout has no ANSI (isatty check)" {
    (stdout, stderr) = run_jac(['run', ERR_FILE]);
    assert not has_ansi(stdout) , f"ANSI in stdout: {repr(stdout[:200])}";
}

test "piped stderr has no ANSI (isatty check)" {
    (stdout, stderr) = run_jac(['run', ERR_FILE]);
    assert not has_ansi(stderr) , f"ANSI in stderr: {repr(stderr[:200])}";
}

# =============================================================================
# Environment variable overrides
# =============================================================================
test "NO_COLOR=1 disables ANSI" {
    (stdout, stderr) = run_jac(['run', ERR_FILE], {'NO_COLOR': '1'});
    assert not has_ansi(stdout + stderr);
}

test "TERM=dumb disables ANSI" {
    (stdout, stderr) = run_jac(['run', ERR_FILE], {'TERM': 'dumb'});
    assert not has_ansi(stdout + stderr);
}

# =============================================================================
# Output is human readable
# =============================================================================
test "error messages are readable" {
    (stdout, stderr) = run_jac(['run', ERR_FILE]);
    combined = stdout + stderr;
    assert 'Error' in combined or 'error' in combined or '✖' in combined;
}

# =============================================================================
# Encoding: escape sequences and non-ASCII chars in f-strings (raw_unicode_escape fix)
# =============================================================================
test "fstring escape sequences are decoded correctly" {
    (stdout, _) = run_jac(['run', FSTRING_ENCODING_FILE]);
    assert 'ESC_NEWLINE:\nhello world' in stdout , "\\n escape not decoded in f-string";
    assert 'ESC_TAB:\there world' in stdout , "\\t escape not decoded in f-string";
    assert 'ESC_ANSI:\x1b[0mworld' in stdout , "\\x1b escape not decoded in f-string";
    assert 'UNICODE_A:A world' in stdout , "\\uXXXX escape not decoded in f-string";
    assert 'CHINESE:你好 world' in stdout , "Chinese chars garbled in f-string";
    assert 'ARABIC:مرحبا world' in stdout , "Arabic chars garbled in f-string";
}

test "4-byte emoji literals in f-strings are not garbled" {
    (stdout, _) = run_jac(['run', FSTRING_ENCODING_FILE]);
    assert 'EMOJI_BOOK:📚 world' in stdout , "📚 garbled in f-string";
    assert 'EMOJI_CHAT:💬 world' in stdout , "💬 garbled in f-string";
    assert 'EMOJI_BUG:🐛 world' in stdout , "🐛 garbled in f-string";
    assert 'EMOJI_ROCKET:🚀 world' in stdout , "🚀 garbled in f-string";
    assert '📚 world 💬' in stdout , "emoji mixed with escape sequence garbled in f-string";
    assert '\xc3\xb0' not in stdout , "double-encoded emoji byte found — raw_unicode_escape fix regression";
}

# =============================================================================
# Regression: user data with special patterns preserved unchanged
# =============================================================================
# =============================================================================
# Windows encoding: unencodable chars replaced instead of crash
# =============================================================================
test "Windows console encoding handles unencodable Unicode" {
    # This test verifies that characters outside cp1252 don't crash on Windows.
    # On Windows cmd/PowerShell (without WT_SESSION), unencodable chars are replaced.
    # On Linux/Mac/Windows Terminal, they pass through unchanged.
    (stdout, _) = run_jac(['run', FSTRING_ENCODING_FILE]);

    # The file contains emoji (📚💬🐛🚀) which can't be encoded in cp1252.
    # Test should not crash - output should contain either the emoji or replacement char.
    assert len(stdout) > 0 , "No output - possible encoding crash";

    # At minimum, the ASCII parts should always be present
    assert 'world' in stdout , "ASCII content missing from output";
    assert 'ESC_NEWLINE' in stdout , "Label missing - possible encoding crash";
}

test "all edge case patterns preserved" {
    (stdout, stderr) = run_jac(['run', EDGE_CASES_FILE]);

    # Patterns that must appear exactly in output
    must_contain = [
        # Hex patterns (caused ValueError crash)
        '#2000',
        '#ff0000',
        '#fff',
        '#123',
        '#abc',
        # Markup-like (were stripped)
        '[red]',
        '[/red]',
        '[bold]',
        '[dim]',
        '[green]',
        '[yellow]',
        '[cyan]',
        # Config sections
        '[section]',
        '[project]',
        '[database]',
        '[tool.mypy]',
        # Array/dict access
        'arr[0]',
        "dict['key']",
        # RGB/color functions
        'rgb(255, 0, 0)',
        'color(196)',
        # URL fragments
        'http://example.com#section',
        # Regex-like
        '[a-z]+',
        '[0-9]{3}',
        # Nested brackets
        '[[nested]]',
        # Error patterns
        '[ERROR]',
        '[INFO]',
        '[INVALID]',
        # Real-world data structures
        '[[0,',  # Nested list start
        "name_0"  # List comprehension data
    ];

    for pattern in must_contain {
        assert pattern in stdout , f"Pattern was corrupted or stripped: {pattern}";
    }
}

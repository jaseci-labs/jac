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
# Regression: user data with special patterns preserved unchanged
# =============================================================================
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

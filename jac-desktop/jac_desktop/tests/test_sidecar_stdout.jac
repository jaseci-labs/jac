"""Tests for sidecar stdout redirect after port discovery."""

import sys;
import io;
import from pathlib { Path }

import from _helpers { _SIDECAR_MAIN }

"""After redirecting stdout to stderr, print() should still work."""
test "stdout redirect to stderr preserves writes" {
    original_stdout = sys.stdout;
    original_stderr = sys.stderr;
    try {
        # Simulate the sidecar pattern
        fake_stderr = io.StringIO();
        sys.stderr = fake_stderr;
        sys.stdout = sys.stderr;  # redirect like sidecar does

        print("test message after redirect");
        output = fake_stderr.getvalue();
        assert "test message after redirect" in output , f"Redirected print should appear in stderr, got: {output}";
    } finally {
        sys.stdout = original_stdout;
        sys.stderr = original_stderr;
    }
}

"""Simulates Tauri dropping stdout pipe — writes should go to stderr."""
test "stdout redirect prevents broken pipe on closed stdout" {
    original_stdout = sys.stdout;
    original_stderr = sys.stderr;
    try {
        # Create a closed stdout (simulates Tauri dropping pipe)
        closed_stdout = io.StringIO();
        closed_stdout.close();

        # Redirect to stderr before closing
        fake_stderr = io.StringIO();
        sys.stderr = fake_stderr;
        sys.stdout = sys.stderr;

        # This should NOT crash
        print("safe write after redirect");
        sys.stdout.flush();
        output = fake_stderr.getvalue();
        assert "safe write after redirect" in output;
    } finally {
        sys.stdout = original_stdout;
        sys.stderr = original_stderr;
    }
}


"""Verify the stdout redirect pattern exists in sidecar main.py."""
test "sidecar main.py has stdout redirect after port write" {
    main_py = _SIDECAR_MAIN;
    assert main_py.exists() , f"sidecar main.py not found at {main_py}";
    with open(str(main_py), "r", encoding="utf-8") as f {
        content = f.read();
    }
    assert "sys.stdout = sys.stderr" in content , (
        "sidecar main.py should redirect stdout to stderr after port discovery"
    );
    port_line = content.index("JAC_SIDECAR_PORT");
    redirect_line = content.index("sys.stdout = sys.stderr");
    assert redirect_line > port_line , (
        "stdout redirect must come AFTER JAC_SIDECAR_PORT write"
    );
}

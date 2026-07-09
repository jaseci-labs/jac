"""Behavioral tests for mobile target end-to-end correctness.

Each test captures a concrete bug observed in QA:
2. Android dep check only probes `java` (JRE), missing `javac` (JDK) — so JRE-only
   installs are certified green and then Gradle fails downstream.
3. `cap run` returning nonzero is followed by a "📱 App deployed" banner that lies
   about deployment state.
4. `_mobile_setup_android_port_reverse` runs unconditionally on Android, emitting
   stack-style warnings when adb is simply not installed.
5. The mobile dev flow reserves a backend port via adb reverse, but the API
   subprocess's port-conflict fallback may bind a different port — so the reserved
   port doesn't match what the device reaches.
"""

import io;
import socket;
import subprocess;
import sys;
import unittest.mock;
import pytest;
import from contextlib { redirect_stdout, redirect_stderr }

import from jaclang.runtimelib.client.targets.mobile.deps {
    _check_android_dependencies
}
import from jaclang.runtimelib.client.targets.mobile.dev {
    _mobile_setup_android_port_reverse
}


# =============================================================================
# Bug #2: dep check must call out missing javac (JDK) even when java (JRE) is present.
# =============================================================================
"""Fake subprocess.run for the (java present, javac absent) scenario."""
def _fake_java_only_run(cmd: list, **kwargs: dict) -> object {
    class _Res {
        has returncode: int = 0,
            stdout: str = "",
            stderr: str = "";
    }
    exe = cmd[0] if cmd else "";
    if exe == "java" {
        r = _Res();
        r.returncode = 0;
        r.stderr = 'openjdk version "21.0.10" 2026-01-20\n'
        "OpenJDK Runtime Environment (build 21.0.10+7-Ubuntu-124.04)";
        return r;
    }
    if exe == "javac" {
        raise FileNotFoundError(2, "No such file or directory", "javac");
    }
    # Other tools (adb, gradle, node) — pretend missing.
    raise FileNotFoundError(2, "No such file or directory", exe);
}

test "android dep check flags missing javac when java is present" {
    buf = io.StringIO();
    with unittest.mock.patch("subprocess.run", side_effect=_fake_java_only_run) as _, redirect_stdout(
        buf
    ), redirect_stderr(buf) {
        _check_android_dependencies();
    }
    out = buf.getvalue().lower();
    assert "javac" in out , (
        "dep check did not mention javac when JRE-only install was simulated; "
        f"output was:\n{buf.getvalue()}"
    );
    assert "jdk" in out , (
        "dep check did not flag missing JDK; output was:\n{}".format(buf.getvalue())
    );
}


# =============================================================================
# Bug #3: cap run completion message must reflect rc; "App deployed" must not
# be printed when `cap run` returned nonzero.
# =============================================================================
test "cap run completion message reflects nonzero return code" {
    import from jaclang.runtimelib.client.targets.mobile.dev {
        _describe_cap_run_completion
    }
    ok_info = _describe_cap_run_completion(0, "http://10.0.2.2:8000");
    fail_info = _describe_cap_run_completion(1, "http://10.0.2.2:8000");

    assert ok_info["ok"] is True;
    assert any("deployed" in m.lower() for m in ok_info["messages"]);

    assert fail_info["ok"] is False;
    # Must not falsely claim success. "App deployed" / "app deployed" was the
    # specific pre-fix string that misled users; "was not deployed" is fine.
    bad_phrases = ["📱 app deployed", "app deployed."];
    for m in fail_info["messages"] {
        m_low = m.lower();
        for phrase in bad_phrases {
            assert phrase not in m_low , (
                f"Failed cap run message falsely claimed deployment: {m}"
            );
        }
    }
    joined = " ".join(fail_info["messages"]).lower();
    assert (
        ("exited with code" in joined)
        or ("not deployed" in joined)
        or ("failed" in joined)
    ) , (
        f"Failed cap run message did not indicate failure; messages={fail_info[
            'messages'
        ]}"
    );
}


# =============================================================================
# Bug #4: adb reverse must skip silently when adb is not on PATH (no warnings).
# =============================================================================
test "adb reverse is skipped silently when adb is missing" {
    calls: list[tuple] = [];

    def _record_run(*a: object, **kw: object) -> object {
        calls.append((a, kw));
        raise FileNotFoundError(2, "No such file or directory", "adb");
    }

    buf = io.StringIO();
    with unittest.mock.patch("shutil.which", side_effect=lambda name : None ) as _, unittest.mock.patch(
        "subprocess.run", side_effect=_record_run
    ) as _, redirect_stdout(buf), redirect_stderr(buf) {
        _mobile_setup_android_port_reverse(8000, 8001);
    }

    assert len(calls) == 0 , (
        f"subprocess.run was called {len(calls)} times when adb was missing; "
        "the helper must guard with shutil.which('adb')."
    );
    out = buf.getvalue().lower();
    assert "no such file" not in out , (
        "Missing-adb scenario must not emit '[Errno 2] No such file' warnings; "
        f"output was:\n{buf.getvalue()}"
    );
    assert "adb reverse failed" not in out , (
        "Missing-adb scenario must not warn that 'adb reverse failed'; "
        f"output was:\n{buf.getvalue()}"
    );
}


# =============================================================================
# Bug #5: mobile dev needs deterministic ports. A pre-bind probe must fail fast
# when the port is occupied so adb reverse / cap config don't drift away from
# what the API server actually binds.
# =============================================================================
test "port availability check raises when port is already bound" {
    import from jaclang.runtimelib.client.targets.mobile.dev {
        _assert_mobile_port_available
    }

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 0);
    s.bind(("127.0.0.1", 0));
    busy_port = s.getsockname()[1];
    s.listen(1);
    try {
        with pytest.raises(RuntimeError) as exc_info {
            _assert_mobile_port_available(busy_port, "API");
        }
        msg = str(exc_info.value);
        assert str(busy_port) in msg , (
            f"Error must mention the offending port ({busy_port}); got: {msg}"
        );
        assert "api" in msg.lower() , (
            f"Error must mention the role of the port (API); got: {msg}"
        );
    } finally {
        s.close();
    }
}

test "port availability check passes for an unbound port" {
    import from jaclang.runtimelib.client.targets.mobile.dev {
        _assert_mobile_port_available
    }

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM);
    s.bind(("127.0.0.1", 0));
    free_port = s.getsockname()[1];
    s.close();
    # Should not raise.
    _assert_mobile_port_available(free_port, "API");
}

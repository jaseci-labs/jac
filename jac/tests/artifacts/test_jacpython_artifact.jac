"""JacPython is the only Python: `jac native build jacpython` is `zig build`,
which makes zig-out/bin/jac on it. A jac that predates it says where the build
is, quietly, and the build still counts as current."""

import io;
import os;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from unittest.mock { patch }
import from jaclang.artifacts.model { Source }
import jaclang.artifacts.router as router;
import jaclang.dist.interpreter as interpreter;
import from jaclang.dist.interpreter { JacPythonArtifact }

def _resolve(running: bool, binary: str) -> tuple[any, str] {
    err = io.StringIO();
    router.forget("jacpython");
    try {
        with patch.object(interpreter, "running_jacpython", return_value=running), patch.object(
            interpreter, "jacpython_binary", return_value=binary
        ), patch.object(JacPythonArtifact, "probe_sealed", return_value=None), patch.object(
            sys, "stderr", err
        ) {
            return (router.resolve("jacpython"), err.getvalue());
        }
    } finally {
        router.forget("jacpython");
    }
}

test "a jac that predates JacPython names the JacPython build quietly" {
    with TemporaryDirectory() as tmp {
        binary = str(Path(tmp) / "bin" / "jac");
        (resolution, said) = _resolve(False, binary);
        assert resolution.on_floor();
        assert "jac native build jacpython" in resolution.reason , resolution.reason;
        assert said == "" , "an older jac is not a fault";
        Path(binary).parent.mkdir(parents=True);
        Path(binary).write_text("");
        (resolution, said) = _resolve(False, binary);
        assert resolution.on_floor() and binary in resolution.reason , resolution.reason;
        assert said == "";
    }
}

test "a jac on JacPython uses it" {
    (resolution, said) = _resolve(True, "/nowhere/jac");
    assert resolution.found is not None;
    assert resolution.found.source == Source.CHECKOUT;
    assert resolution.found.path == sys.executable;
}

test "the build is current once its binary exists, whatever this process runs" {
    with TemporaryDirectory() as tmp {
        binary = str(Path(tmp) / "jac");
        with patch.object(interpreter, "jacpython_binary", return_value=binary), patch.object(
            interpreter, "running_jacpython", return_value=False
        ) {
            artifact = JacPythonArtifact();
            assert artifact.built().found is None;
            Path(binary).write_text("");
            assert artifact.built().found is not None;
            assert artifact.probe_checkout().found is None;
        }
    }
}

test "a build is a plain zig build of zig-out/bin/jac" {
    calls: list[list[str]] = [];
    def run(argv: list[str], **kwargs: any) -> any {
        calls.append(list(argv));
        return None;
    }
    with patch("subprocess.run", side_effect=run), patch.object(
        interpreter, "jacpython_binary", return_value="/repo/jac/zig-out/bin/jac"
    ) {
        JacPythonArtifact().build(lambda (line: str) {}, False, False);
        JacPythonArtifact().build(lambda (line: str) {}, False, True);
    }
    assert calls[0][:4] == ["zig", "build", "--prefix", "/repo/jac/zig-out"] , calls;
    assert "-Dreuse-python=true" in calls[0] and "-Dreuse-python=true" not in calls[1];
}

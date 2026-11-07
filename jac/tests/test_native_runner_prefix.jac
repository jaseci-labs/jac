import os;
import shlex;
import tempfile;
import unittest.mock;
import from pathlib { Path }
import from tests.support { native_run }

def _runner_script(directory: Path, filename: str, body: str) -> Path {
    script = directory / filename;
    script.write_text("#!/bin/sh\n" + body);
    script.chmod(0o755);
    return script;
}

test "native runner without prefix preserves direct argv and stdout" {
    with tempfile.TemporaryDirectory(prefix="native-runner-") as directory {
        executable = _runner_script(
            Path(directory), "native binary", "printf '<%s>\\n' \"$0\" \"$@\"\n"
        );
        with unittest.mock.patch.dict(os.environ) {
            os.environ.pop("JAC_TEST_NATIVE_RUNNER", None);
            output = native_run(str(executable), ["two words", "quote'quote", ""]);
        }
        assert output == f"<{executable}>\n<two words>\n<quote'quote>\n<>\n";
    }
}

test "native runner prefix preserves quoted argv and per-call environment" {
    with tempfile.TemporaryDirectory(prefix="native-runner-") as directory {
        runner = _runner_script(
            Path(directory), "runner with spaces", "printf '<%s>\\n' \"$@\"\n"
        );
        target = str(Path(directory) / "native target with spaces");
        prefix = shlex.quote(str(runner)) + " " + shlex.quote("prefix argument");
        with unittest.mock.patch.dict(
            os.environ, {"JAC_TEST_NATIVE_RUNNER": "/missing-inherited-runner"}
        ) {
            output = native_run(
                target,
                ["two words", "quote'quote", ""],
                env={"JAC_TEST_NATIVE_RUNNER": prefix}
            );
        }
        assert output
            == f"<prefix argument>\n<{target}>\n<two words>\n<quote'quote>\n<>\n";
    }
}

test "native runner nonzero exit preserves the existing failure diagnostics" {
    with tempfile.TemporaryDirectory(prefix="native-runner-") as directory {
        runner = _runner_script(
            Path(directory),
            "failing runner",
            "printf 'runner stdout\\n'\nprintf 'runner stderr\\n' >&2\nexit 29\n"
        );
        detail: str | None = None;
        try {
            native_run(
                "native target",
                env={"JAC_TEST_NATIVE_RUNNER": shlex.quote(str(runner))}
            );
        } except AssertionError as error {
            detail = str(error);
        }
        assert detail is not None;
        assert "native target exited 29" in detail;
        assert "runner stdout" in detail;
        assert "runner stderr" in detail;
    }
}

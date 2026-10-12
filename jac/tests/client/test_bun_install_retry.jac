"""A dependency install that fails once is retried, so one bad registry response
does not fail the build; an install that keeps failing still raises."""

import os;
import stat;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }
import from jaclang.client.vite_bundler { ViteBundler }
import from jaclang.client.client_bundle { ClientBundleError }


def _fake_bun(base: Path, failures: int) -> Path {
    calls = base / "calls";
    calls.write_text("");
    script = base / "bun";
    script.write_text(
        "#!/bin/sh\n"
        f"echo x >> '{calls}'\n"
        f"if [ \"$(wc -l < '{calls}')\" -le {failures} ]; then\n"
        "  echo 'error: GET https://registry.npmjs.org/pkg/-/pkg-1.0.0.tgz - 404' >&2\n"
        "  exit 1\n"
        "fi\n"
        "mkdir -p node_modules\n"
    );
    script.chmod(script.stat().st_mode | stat.S_IXUSR);
    return script;
}


def _install(base: Path, failures: int) -> int {
    build_dir = base / "client";
    (build_dir / "configs").mkdir(parents=True);
    (build_dir / "configs" / "package.json").write_text('{"name": "app"}');
    bun = _fake_bun(base, failures);
    with patch("jaclang.client.vite_bundler._require_bun", return_value=str(bun)), patch(
        "jaclang.client.vite_bundler.BUN_INSTALL_RETRY_PAUSE_SECONDS", 0
    ) {
        ViteBundler(base).install_packages(
            install_dir=build_dir, force=True, capture_output=True
        );
    }
    return len((base / "calls").read_text().splitlines());
}


test "an install that fails once is retried and succeeds" {
    with tempfile.TemporaryDirectory() as tmp {
        calls = _install(Path(tmp), failures=1);
        assert calls == 2 , f"bun install ran {calls} time(s)";
    }
}


test "an install that keeps failing raises after the last attempt" {
    with tempfile.TemporaryDirectory() as tmp {
        raised: (ClientBundleError | None) = None;
        try {
            _install(Path(tmp), failures=99);
        } except ClientBundleError as e {
            raised = e;
        }
        assert raised is not None , "a failing install must raise";
        assert "404" in str(raised) , str(raised);
        calls = len((Path(tmp) / "calls").read_text().splitlines());
        assert calls == 3 , f"bun install ran {calls} time(s)";
    }
}

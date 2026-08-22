"""Bun resolution: source checkouts have no bundled copy, so a bun already
on PATH (or the conventional ~/.bun install) must be picked up before
failing -- every fresh editable dev loop hit the hard error otherwise."""

import os;
import stat;
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.client.bun_installer { _find_path_bun }

test "path fallback finds a bun on PATH" {
    with TemporaryDirectory() as td {
        fake = os.path.join(td, "bun");
        with open(fake, "w") as f {
            f.write("#!/bin/sh\nexit 0\n");
        }
        os.chmod(fake, 0o755);
        old_path = os.environ.get("PATH", "");
        old_home = os.environ.get("HOME", "");
        os.environ["PATH"] = td;
        os.environ["HOME"] = td;
        try {
            found = _find_path_bun();
            assert found == fake , f"expected {fake}, got {found}";
        } finally {
            os.environ["PATH"] = old_path;
            os.environ["HOME"] = old_home;
        }
    }
}

test "path fallback returns None when no bun exists anywhere" {
    with TemporaryDirectory() as td {
        old_path = os.environ.get("PATH", "");
        old_home = os.environ.get("HOME", "");
        os.environ["PATH"] = td;
        os.environ["HOME"] = td;
        try {
            assert _find_path_bun() is None;
        } finally {
            os.environ["PATH"] = old_path;
            os.environ["HOME"] = old_home;
        }
    }
}

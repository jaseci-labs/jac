"""js_engine resolution: source checkouts have no bundled copy, so a js_engine already
on PATH must be picked up before
failing -- every fresh editable dev loop hit the hard error otherwise."""

import os;
import stat;
import from tempfile { TemporaryDirectory }
import from jaclang.client.js_engine { _find_path_js_engine }

test "path fallback finds a js_engine on PATH" {
    with TemporaryDirectory() as td {
        fake = os.path.join(td, "js_engine");
        with open(fake, "w") as f {
            f.write("#!/bin/sh\nexit 0\n");
        }
        os.chmod(fake, 0o755);
        old_path = os.environ.get("PATH", "");
        old_home = os.environ.get("HOME", "");
        os.environ["PATH"] = td;
        os.environ["HOME"] = td;
        try {
            found = _find_path_js_engine();
            assert found == fake , f"expected {fake}, got {found}";
        } finally {
            os.environ["PATH"] = old_path;
            os.environ["HOME"] = old_home;
        }
    }
}

test "path fallback returns None when no js_engine exists anywhere" {
    with TemporaryDirectory() as td {
        old_path = os.environ.get("PATH", "");
        old_home = os.environ.get("HOME", "");
        os.environ["PATH"] = td;
        os.environ["HOME"] = td;
        try {
            assert _find_path_js_engine() is None;
        } finally {
            os.environ["PATH"] = old_path;
            os.environ["HOME"] = old_home;
        }
    }
}

"""Bun is an artifact the router resolves: the sealed image's, the checkout's
(fetched by `jac native build bun`) or the kit's, each accepted only when it is
the pinned version, read from its record or, with no record, asked of the
binary. Nothing scans PATH."""

import json;
import os;
import from tempfile { TemporaryDirectory }
import from jaclang.artifacts.model { Source }
import from jaclang.client.js_runtime {
    BUN_VERSION,
    RECORD_SUFFIX,
    _probe_bun,
    write_bun_record
}

def _fake_bun(directory: str, reports: str = "") -> str {
    path = os.path.join(directory, "bun");
    with open(path, "w") as f {
        f.write(f"#!/bin/sh\necho {reports}\n" if reports else "#!/bin/sh\nexit 0\n");
    }
    return path;
}

test "a bun carrying the pinned version's record is current, and made executable" {
    with TemporaryDirectory() as td {
        bun = _fake_bun(td);
        write_bun_record(bun);
        found = _probe_bun(bun, Source.CHECKOUT);
        assert found.found is not None and found.found.path == bun;
        assert os.access(bun, os.X_OK);
    }
}

test "a bun of another or unknown version is stale" {
    with TemporaryDirectory() as td {
        bun = _fake_bun(td);
        unrecorded = _probe_bun(bun, Source.CHECKOUT);
        assert unrecorded.found is None and "unknown version" in unrecorded.drift[0];
        with open(bun + RECORD_SUFFIX, "w") as f {
            json.dump({"version": "0.0.1"}, f);
        }
        old = _probe_bun(bun, Source.CHECKOUT);
        assert old.found is None and BUN_VERSION in old.drift[0];
    }
}

test "a missing bun is missing" {
    with TemporaryDirectory() as td {
        assert _probe_bun(os.path.join(td, "bun"), Source.CHECKOUT).absent;
    }
}


test "a bun with no record is current when the binary reports the pinned version" {
    with TemporaryDirectory() as td {
        bun = _fake_bun(td, reports=BUN_VERSION);
        found = _probe_bun(bun, Source.KIT);
        assert found.found is not None and found.found.path == bun;
        assert not os.path.exists(bun + RECORD_SUFFIX);
    }
}


test "a bun with no record that reports another version is stale and names it" {
    with TemporaryDirectory() as td {
        bun = _fake_bun(td, reports="1.2.0");
        stale = _probe_bun(bun, Source.KIT);
        assert stale.found is None and "bun 1.2.0 is not the pinned" in stale.drift[0];
    }
}


test "a bun recorded at another version is rejected without touching its permissions" {
    with TemporaryDirectory() as td {
        bun = _fake_bun(td);
        os.chmod(bun, 0o644);
        with open(bun + RECORD_SUFFIX, "w") as f {
            json.dump({"version": "0.0.1"}, f);
        }
        stale = _probe_bun(bun, Source.CHECKOUT);
        assert stale.found is None and "bun 0.0.1 is not the pinned" in stale.drift[0];
        assert not os.access(bun, os.X_OK);
    }
}


test "a bun whose permissions cannot be repaired is unusable, not an error" {
    import from unittest.mock { patch }
    with TemporaryDirectory() as td {
        bun = _fake_bun(td);
        os.chmod(bun, 0o644);
        write_bun_record(bun);
        with patch(
            "jaclang.client.js_runtime.os.chmod",
            side_effect=PermissionError("not owner")
        ) {
            stale = _probe_bun(bun, Source.CHECKOUT);
        }
        assert stale.found is None and "not executable" in stale.drift[0];
    }
}

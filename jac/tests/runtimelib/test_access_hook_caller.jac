"""Tests for the caller-aware access hook (issue #8459).

The zero-arg __jac_access__ cannot see who is calling and the owner
fast-path pre-empts it, so a per-caller role was only expressible as an
endpoint check. __jac_access_for__(caller) runs before the owner fast-path:
ownership admits, the role decides. Driven through the real CLI runner with
multiple real roots and no app-level checks in any handler.
"""

import io;
import os;
import sys;
import shutil;
import from tests.support { JAC_ROOT }
import from tempfile { mkdtemp }
import jaclang;
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "runtimelib", "fixtures"),
     FIXTURE = os.path.join(FIXTURES, "access_hook_caller.jac");

def capture_start -> io.StringIO {
    captured = io.StringIO();
    sys.stdout = captured;
    return captured;
}

def capture_get(captured: io.StringIO) -> str {
    sys.stdout = sys.__stdout__;
    return captured.getvalue();
}

def _run(entrypoint: str, args: (list | None) = None, root_id: str = "") -> str {
    captured = capture_start();
    execution.run(
        filename=FIXTURE, entry_name=entrypoint, args=args or [], root_id=root_id
    );
    return capture_get(captured).strip();
}

def _read(doc: str, as_root: str) -> str {
    out = _run("read_doc", args=[doc], root_id=as_root);
    for ln in out.split("\n") {
        if ln.startswith("READ:") {
            return ln[5:];
        }
    }
    return "";
}

test "the hook sees the caller: editors write, viewers read, at the seam" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        owner = _run("create_other_root");
        editor = _run("create_other_root");
        viewer = _run("create_other_root");
        doc = _run("create_doc", args=[editor], root_id=owner);
        assert doc , "fixture create failed";

        # Everyone can read: the hook floors at READ, no grants exist.
        assert _read(doc, editor) == "original";
        assert _read(doc, viewer) == "original";

        # The editor's cross-user write persists.
        _run("write_doc", args=[doc, "edited"], root_id=editor);
        assert _read(doc, owner) == "edited" , "editor write did not persist";

        # The viewer's write is dropped at the seam, not by any endpoint.
        _run("write_doc", args=[doc, "TAMPERED"], root_id=viewer);
        assert _read(doc, owner) == "edited" , "viewer write persisted";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "ownership admits but the role decides: the owner can be held to READ" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        owner = _run("create_other_root");
        editor = _run("create_other_root");
        doc = _run("create_doc", args=[editor], root_id=owner);

        # The owner is not in editors, so the hook holds the owner to READ.
        _run("write_doc", args=[doc, "OWNER-EDIT"], root_id=owner);
        assert _read(doc, editor) == "original" , (
            "owner bypassed the caller-aware policy"
        );
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "archetypes without the hook behave exactly as before" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        owner = _run("create_other_root");
        other = _run("create_other_root");
        doc = _run("create_plain", root_id=owner);

        # Owner writes; a stranger cannot even resolve it.
        _run("write_doc", args=[doc, "mine"], root_id=owner);
        assert _read(doc, owner) == "mine";
        assert _read(doc, other) == "none";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

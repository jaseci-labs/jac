"""Tests for owner-bound save (issue #8458).

App code can mint a group root, but every anchor used to take its owner from
the ambient caller root with no override, so a member granted on the group
root read nothing: the group owned nothing. These tests drive the real CLI
runner with multiple real roots and prove content can be created under a
group root the caller may write to, that the root-grant cascade then reaches
it, and that the authorization on the owner parameter fails loud.
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
     FIXTURE = os.path.join(FIXTURES, "save_owner.jac");

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

def _line(out: str, prefix: str) -> str {
    for ln in out.split("\n") {
        if ln.startswith(prefix) {
            return ln[len(prefix):];
        }
    }
    return "";
}

test "content can be owned by a group root and the cascade reaches it" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        alice = _run("create_other_root");
        bob = _run("create_other_root");
        org = _run("mint_org_root", root_id=alice);

        out = _run("create_for_org", args=[org, "doc-1"], root_id=alice);
        item = _line(out, "ITEM:");
        assert item , f"owner-bound create failed: {out!r}";
        assert _line(out, "OWNER:") == org , (
            f"item not owned by the org root: {out!r}"
        );

        # Control: without a grant, the other user reads nothing.
        ungranted = _line(_run("read_item", args=[item], root_id=bob), "READ:");
        assert ungranted == "none" , "ungranted member could read org content";

        # One grant on the org root covers the org's content (the cascade).
        _run("grant_on_org", args=[org, bob, "READ"], root_id=alice);
        got = _line(_run("read_item", args=[item], root_id=bob), "READ:");
        assert got == "doc-1" , f"cascade read failed: {got!r}";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "creating under a root without WRITE on it fails loud" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        alice = _run("create_other_root");
        bob = _run("create_other_root");
        eve = _run("create_other_root");
        org = _run("mint_org_root", root_id=alice);
        _run("grant_on_org", args=[org, bob, "READ"], root_id=alice);

        # READ on the org root is not enough to create under it.
        out = _run("create_for_org", args=[org, "sneak"], root_id=bob);
        assert "DENIED:create_for_org" in out , f"READ member created: {out!r}";

        # No grant at all is not enough either.
        out = _run("create_for_org", args=[org, "sneak"], root_id=eve);
        assert "DENIED:create_for_org" in out , f"stranger created: {out!r}";

        # WRITE on the org root is.
        _run("grant_on_org", args=[org, bob, "WRITE"], root_id=alice);
        out = _run("create_for_org", args=[org, "legit"], root_id=bob);
        assert _line(out, "ITEM:") , f"WRITE member denied: {out!r}";
        assert _line(out, "OWNER:") == org;
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "a persistent anchor cannot be re-owned and a non-root owner is refused" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        alice = _run("create_other_root");
        org = _run("mint_org_root", root_id=alice);

        out = _run("create_for_org", args=[org, "doc"], root_id=alice);
        item = _line(out, "ITEM:");
        assert item;

        org2 = _run("mint_org_root", root_id=alice);
        out = _run("try_reown", args=[item, org2], root_id=alice);
        assert "REOWN:refused" in out , f"re-own allowed: {out!r}";

        # A non-root anchor cannot be an owner.
        out = _run("create_for_org", args=[item, "bad"], root_id=alice);
        assert out.startswith("INVALID:") , f"non-root owner accepted: {out!r}";

        # Ownership stays the caller when no owner is passed.
        out2 = _run("create_for_org", args=[org, "keep"], root_id=alice);
        assert _line(out2, "OWNER:") == org;
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

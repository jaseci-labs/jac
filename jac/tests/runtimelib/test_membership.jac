"""Membership end to end (jac#10414).

Every call runs as one real root through the CLI runner, so each is its own
request: the principal set is rebuilt from `Member` edges in the store, and a
typed hop (SQL) and an untyped hop (object space) must agree on what is
visible.
"""

import io;
import sys;
import shutil;
import os;
import from tests.support { JAC_ROOT }
import from tempfile { mkdtemp }
import jaclang;
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }

glob FIXTURE = os.path.join(
         JAC_ROOT, "tests", "runtimelib", "fixtures", "membership.jac"
     );

def _run(entrypoint: str, args: (list[str] | None) = None, root_id: str = "") -> str {
    captured = io.StringIO();
    sys.stdout = captured;
    try {
        execution.run(
            target=FIXTURE, entry_name=entrypoint, args=args or [], root_id=root_id
        );
    } finally {
        sys.stdout = sys.__stdout__;
    }
    return captured.getvalue().strip();
}

def _line(out: str, prefix: str) -> str {
    for ln in out.split("\n") {
        if ln.startswith(prefix) {
            return ln[len(prefix):];
        }
    }
    return "";
}

"""Run in a fresh store and return the base path to restore."""
def _fresh -> tuple[str, str] {
    tmp = mkdtemp();
    orig = Jac.get_base_path_dir() or "";
    Jac.set_base_path(tmp);
    return (tmp, orig);
}

def _done(state: tuple[str, str]) {
    Jac.set_base_path(state[1]);
    shutil.rmtree(state[0], ignore_errors=True);
}

"""alice creates Acme with Plan and Budget; bob, carol and dave are users."""
def _acme -> dict[str, str] {
    w: dict[str, str] = {};
    for name in ("alice", "bob", "carol", "dave", "shane") {
        w[name] = _run("new_user");
    }
    w["acme"] = _run("new_org", args=["Acme"], root_id=w["alice"]);
    w["plan"] = _line(
        _run("add_doc", args=[w["acme"], "Plan"], root_id=w["alice"]), "DOC:"
    );
    w["budget"] = _line(
        _run("add_doc", args=[w["acme"], "Budget"], root_id=w["alice"]), "DOC:"
    );
    return w;
}

def _level(w: dict[str, str], who: str, target: str) -> str {
    return _line(_run("level_of", args=[w[target]], root_id=w[who]), "LEVEL:");
}

test "the creator of a group is its admin and finds it from their root" {
    state = _fresh();
    try {
        w = _acme();
        assert _level(w, "alice", "acme") == "ADMIN";
        assert _line(_run("my_groups", root_id=w["alice"]), "GROUPS:") == "Workspace";
        assert _line(_run("owner_of", args=[w["plan"]], root_id=w["alice"]), "OWNER:")
            == w["acme"] , "a doc attached under the org is not owned by the org";
        assert _line(_run("my_groups", root_id=w["bob"]), "GROUPS:") == "";
    } finally {
        _done(state);
    }
}

test "a member gets their level on everything the group owns, in both read paths" {
    state = _fresh();
    try {
        w = _acme();
        _run("share", args=[w["acme"], w["bob"], "WRITE"], root_id=w["alice"]);
        _run("share", args=[w["acme"], w["carol"], "READ"], root_id=w["alice"]);
        for (who, level, seen) in [
            ("alice", "ADMIN", "2"),
            ("bob", "WRITE", "2"),
            ("carol", "READ", "2"),
            ("dave", "NO_ACCESS", "0")
        ] {
            assert _level(w, who, "plan") == level , f"{who} on Plan";
            out = _run("visible", args=[w["acme"]], root_id=w[who]);
            assert _line(out, "TYPED:") == seen , f"{who} typed hop: {out!r}";
            assert _line(out, "UNTYPED:") == seen , f"{who} untyped hop: {out!r}";
        }
        assert _line(_run("my_groups", root_id=w["bob"]), "GROUPS:") == "Workspace";
    } finally {
        _done(state);
    }
}

test "only an admin changes access" {
    state = _fresh();
    try {
        w = _acme();
        _run("share", args=[w["acme"], w["bob"], "WRITE"], root_id=w["alice"]);
        for (walker, args) in [
            ("share", [w["acme"], w["dave"], "READ"]),
            ("unshare", [w["acme"], w["alice"]]),
            ("make_public", [w["plan"], "READ"])
        ] {
            out = _run(walker, args=args, root_id=w["bob"]);
            assert ":DENIED" in out and "needs ADMIN" in out , f"{walker} as WRITE: {out!r}";
        }
        assert _level(w, "dave", "plan") == "NO_ACCESS";
        _run("share", args=[w["acme"], w["bob"], "ADMIN"], root_id=w["alice"]);
        out = _run("share", args=[w["acme"], w["dave"], "READ"], root_id=w["bob"]);
        assert _line(out, "SET:") == "None" , out;
        assert _level(w, "dave", "plan") == "READ";
    } finally {
        _done(state);
    }
}

test "sharing a node shares what is under it and nothing above it" {
    state = _fresh();
    try {
        w = _acme();
        _run("share", args=[w["acme"], w["bob"], "WRITE"], root_id=w["alice"]);
        doc1 = _line(
            _run("add_doc", args=[w["acme"], "Doc1"], root_id=w["alice"]), "DOC:"
        );
        page1 = _line(
            _run("add_doc", args=[doc1, "Page1"], root_id=w["alice"]), "DOC:"
        );
        _run("share", args=[doc1, w["shane"], "WRITE"], root_id=w["alice"]);
        w["doc1"] = doc1;
        w["page1"] = page1;

        assert _line(_run("owner_of", args=[page1], root_id=w["alice"]), "OWNER:")
            == doc1 , "the shared node did not take over its subtree";
        for (who, target, level) in [
            ("shane", "doc1", "WRITE"),
            ("shane", "page1", "WRITE"),
            ("shane", "plan", "NO_ACCESS"),
            ("shane", "acme", "NO_ACCESS"),
            ("alice", "page1", "ADMIN"),
            ("bob", "page1", "WRITE")
        ] {
            assert _level(w, who, target) == level , f"{who} on {target}";
        }
        out = _run("visible", args=[doc1], root_id=w["shane"]);
        assert _line(out, "TYPED:") == "1" and _line(out, "UNTYPED:") == "1" , out;

        # What shane adds under Doc1 belongs to Doc1, so alice sees it too.
        out = _run("add_doc", args=[doc1, "Page2"], root_id=w["shane"]);
        assert _line(out, "OWNER:") == doc1 , out;
        page2 = _line(out, "DOC:");
        assert _line(_run("level_of", args=[page2], root_id=w["alice"]), "LEVEL:")
            == "ADMIN";
    } finally {
        _done(state);
    }
}

test "a block holds against every grant except an admin above it" {
    state = _fresh();
    try {
        w = _acme();
        _run("share", args=[w["acme"], w["bob"], "WRITE"], root_id=w["alice"]);
        _run("make_public", args=[w["budget"], "READ"], root_id=w["alice"]);
        _run("share", args=[w["budget"], w["bob"], "NO_ACCESS"], root_id=w["alice"]);
        assert _level(w, "bob", "budget") == "NO_ACCESS";
        assert _level(w, "bob", "plan") == "WRITE";
        assert _level(w, "dave", "budget") == "READ" , "the block leaked to others";
        out = _run("visible", args=[w["acme"]], root_id=w["bob"]);
        assert _line(out, "TYPED:") == "1" and _line(out, "UNTYPED:") == "1" , out;

        out = _run(
            "share", args=[w["budget"], w["alice"], "NO_ACCESS"], root_id=w["alice"]
        );
        assert _level(w, "alice", "budget") == "ADMIN" , f"an admin was blocked: {out!r}";
    } finally {
        _done(state);
    }
}

test "clearing access removes it and the last admin cannot leave" {
    state = _fresh();
    try {
        w = _acme();
        _run("share", args=[w["acme"], w["bob"], "WRITE"], root_id=w["alice"]);
        _run("unshare", args=[w["acme"], w["bob"]], root_id=w["alice"]);
        assert _level(w, "bob", "plan") == "NO_ACCESS";
        assert _line(_run("my_groups", root_id=w["bob"]), "GROUPS:") == "";

        # Anyone can leave; the last admin cannot.
        _run("share", args=[w["acme"], w["carol"], "READ"], root_id=w["alice"]);
        out = _run("unshare", args=[w["acme"], w["carol"]], root_id=w["carol"]);
        assert _line(out, "CLEAR:") == "None" , out;
        assert _level(w, "carol", "plan") == "NO_ACCESS";
        out = _run("unshare", args=[w["acme"], w["alice"]], root_id=w["alice"]);
        assert "would have no admin" in out , out;
        assert _level(w, "alice", "plan") == "ADMIN";
    } finally {
        _done(state);
    }
}

test "membership changes only through set_access and clear_access" {
    state = _fresh();
    try {
        w = _acme();
        _run("share", args=[w["acme"], w["bob"], "WRITE"], root_id=w["alice"]);
        out = _run("connect_member", args=[w["acme"]], root_id=w["dave"]);
        assert "set_access" in out and "linked" not in out , out;
        _run("promote_self", args=[w["acme"]], root_id=w["bob"]);
        assert _level(w, "bob", "acme") == "WRITE" , "a member promoted themselves";
        out = _run("delete_own_edge", args=[w["acme"]], root_id=w["bob"]);
        assert "clear_access" in out , out;
        for (who, err) in [(w["acme"], "member of itself"), ("0" * 32, "system")] {
            out = _run("share", args=[w["acme"], who, "READ"], root_id=w["alice"]);
            assert ":INVALID" in out , f"{who}: {out!r}";
        }
    } finally {
        _done(state);
    }
}

test "public access cannot be ADMIN and an unchanged grant needs no rights" {
    state = _fresh();
    try {
        w = _acme();
        out = _run("make_public", args=[w["plan"], "ADMIN"], root_id=w["alice"]);
        assert ":INVALID" in out , out;
        _run("make_public", args=[w["plan"], "WRITE"], root_id=w["alice"]);
        out = _run("make_public", args=[w["plan"], "WRITE"], root_id=w["dave"]);
        assert _line(out, "GRANT:") == "None" , f"a no-op grant was refused: {out!r}";
        assert _level(w, "dave", "plan") == "WRITE";
    } finally {
        _done(state);
    }
}

test "a group can be a member, and its members are capped by both levels" {
    state = _fresh();
    try {
        w = _acme();
        w["team"] = _run("new_org", args=["Team"], root_id=w["alice"]);
        _run("share", args=[w["team"], w["carol"], "WRITE"], root_id=w["alice"]);
        _run("share", args=[w["team"], w["dave"], "READ"], root_id=w["alice"]);
        _run("share", args=[w["plan"], w["team"], "WRITE"], root_id=w["alice"]);
        _run("share", args=[w["budget"], w["team"], "READ"], root_id=w["alice"]);
        for (who, target, level) in [
            ("carol", "plan", "WRITE"),
            ("dave", "plan", "READ"),
            ("carol", "budget", "READ"),
            ("bob", "plan", "NO_ACCESS")
        ] {
            assert _level(w, who, target) == level , f"{who} on {target}";
        }
        out = _run("visible", args=[w["acme"]], root_id=w["carol"]);
        assert _line(out, "TYPED:") == "2" and _line(out, "UNTYPED:") == "2" , out;
    } finally {
        _done(state);
    }
}

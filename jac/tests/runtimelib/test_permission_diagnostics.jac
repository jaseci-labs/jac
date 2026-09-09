"""Tests for permission-denial diagnostics (issue #5788).

Validates that cross-user write attempts (edge create, field mutation,
delete) emit a typed PermissionDenied diagnostic on the request-scoped
ExecutionContext.diagnostics list - replacing the prior silent no-op
that returned 200 OK with no signal.

Also covers the strict-mode escape hatch: when JacRuntime.strict_permissions
is True (or JAC_STRICT_PERMISSIONS env var is truthy), the runtime raises
PermissionError instead of accumulating + continuing.
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
     FIXTURE = os.path.join(FIXTURES, "permission_diagnostics.jac");

def capture_start -> io.StringIO {
    captured = io.StringIO();
    sys.stdout = captured;
    return captured;
}

def capture_get(captured: io.StringIO) -> str {
    sys.stdout = sys.__stdout__;
    return captured.getvalue();
}

def _run(entrypoint: str, args: list = [], root_id: str = "", nd: str = "") -> str {
    captured = capture_start();
    execution.run(
        target=FIXTURE, entry_name=entrypoint, args=args, root_id=root_id, nd=nd
    );
    return capture_get(captured).strip();
}

"""Return (alice_root_id, bob_root_id, alice_profile_id) with READ grant."""
def _setup_alice_bob -> tuple[(str, str, str)] {
    alice = _run("create_other_root");
    bob = _run("create_other_root");
    profile_id = _run("create_profile", args=["alice_v1"], root_id=alice);
    # Alice grants READ so Bob can resolve the profile by id, but neither
    # connect nor write.
    _run("grant_profile_to", args=[bob, "READ"], root_id=alice);
    return (alice, bob, profile_id);
}

test "edge write across users emits edge_write diagnostic" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run("try_edge_write", args=[profile_id], root_id=bob);
        diags = [
            line
            for line in out.split("\n")
            if line.startswith("DIAG:")
        ];
        assert len(diags) == 1 , f"expected 1 diagnostic, got {len(diags)}: {diags}";
        # operation, target_type, required, actual
        parts = diags[0].split(":");
        assert parts[1] == "edge_write" , f"expected edge_write, got {parts[1]}";
        assert parts[2] == "Profile";
        # Edge write needs CONNECT; bob has only READ.
        assert parts[3] == "CONNECT";
        assert parts[4] == "READ";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "field write across users emits field_write diagnostic and persist drops" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run("try_field_write", args=[profile_id, "TAMPERED"], root_id=bob);
        diags = [
            line
            for line in out.split("\n")
            if line.startswith("DIAG:")
        ];
        assert len(diags) >= 1 , f"expected >=1 diagnostic, got: {out!r}";
        # At least one must be a field_write on Profile with required=WRITE.
        matches = [
            d
            for d in diags
            if d.startswith("DIAG:field_write:Profile:WRITE:")
        ];
        assert matches , f"expected field_write diagnostic, got: {diags}";
        # Persist-time drop: alice reading her own profile sees the original.
        tag = _run("check_profile_tag", args=[profile_id], root_id=alice);
        assert tag == "alice_v1" , f"expected unchanged tag, got {tag!r}";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "denied field write does not mutate the in-memory archetype" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run(
            "try_field_write_then_read", args=[profile_id, "TAMPERED"], root_id=bob
        );
        lines = out.split("\n");
        tags = [
            line
            for line in lines
            if line.startswith("TAG:")
        ];
        assert tags == ["TAG:alice_v1"] , (
            f"denied assignment must not land in memory, got: {tags}"
        );
        diags = [
            line
            for line in lines
            if line.startswith("DIAG:field_write:")
        ];
        assert diags , f"expected field_write diagnostic, got: {out!r}";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "strict mode raises PermissionError on cross-user field write" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    _orig_strict = Jac.strict_permissions;
    Jac.set_base_path(_tmp);
    Jac.strict_permissions = True;
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        raised = False;
        try {
            _run(
                "try_field_write_then_read", args=[profile_id, "TAMPERED"], root_id=bob
            );
        } except PermissionError {
            raised = True;
        }
        assert raised , (
            "strict mode must raise PermissionError on cross-user field write"
        );
    } finally {
        Jac.strict_permissions = _orig_strict;
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "delete across users emits delete diagnostic and node survives" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run("try_delete", args=[profile_id], root_id=bob);
        diags = [
            line
            for line in out.split("\n")
            if line.startswith("DIAG:")
        ];
        assert len(diags) >= 1 , f"expected >=1 diagnostic, got: {out!r}";
        matches = [
            d
            for d in diags
            if d.startswith("DIAG:delete:Profile:WRITE:")
        ];
        assert matches , f"expected delete diagnostic, got: {diags}";
        # Node still exists from alice's view.
        tag = _run("check_profile_tag", args=[profile_id], root_id=alice);
        assert tag == "alice_v1";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "owner write does not emit diagnostic" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        alice = _run("create_other_root");
        profile_id = _run("create_profile", args=["alice_v1"], root_id=alice);
        out = _run("try_field_write", args=[profile_id, "owner_update"], root_id=alice);
        diags = [
            line
            for line in out.split("\n")
            if line.startswith("DIAG:")
        ];
        assert len(diags) == 0 , f"owner write should not emit diagnostics, got: {diags}";
        tag = _run("check_profile_tag", args=[profile_id], root_id=alice);
        assert tag == "owner_update";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "strict mode raises PermissionError on cross-user edge write" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    _orig_strict = Jac.strict_permissions;
    Jac.set_base_path(_tmp);
    Jac.strict_permissions = True;
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        raised = False;
        try {
            _run("try_edge_write", args=[profile_id], root_id=bob);
        } except PermissionError {
            raised = True;
        }
        assert raised , "strict mode must raise PermissionError on cross-user edge write";
    } finally {
        Jac.strict_permissions = _orig_strict;
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "strict mode raises PermissionError on cross-user delete" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    _orig_strict = Jac.strict_permissions;
    Jac.set_base_path(_tmp);
    Jac.strict_permissions = True;
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        raised = False;
        try {
            _run("try_delete", args=[profile_id], root_id=bob);
        } except PermissionError {
            raised = True;
        }
        assert raised , "strict mode must raise PermissionError on cross-user delete";
    } finally {
        Jac.strict_permissions = _orig_strict;
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

def _lines(out: str, prefix: str) -> list[str] {
    return [
        line
        for line in out.split("\n")
        if line.startswith(prefix)
    ];
}

test "grant across users emits acl_write diagnostic and the grant does not land" {
    # Bob holds READ on alice's profile and tries to grant himself WRITE.
    # An ACL write is a write on the node: it is refused at the call, under
    # bob's principal, so nothing is left in memory for a later flush by
    # anyone (alice, the close, the super root) to persist.
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run("try_acl_grant", args=[profile_id, bob, "WRITE"], root_id=bob);
        diags = _lines(out, "DIAG:");
        assert diags == ["DIAG:acl_write:Profile:WRITE:READ"] , (
            f"expected one acl_write diagnostic at the call, got: {diags}"
        );
        # From alice's view bob is still a reader, in memory and in the store.
        level = _run("check_grant_level", args=[profile_id, bob], root_id=alice);
        assert _lines(level, "LEVEL:") == ["LEVEL:READ"] , (
            f"self-grant landed: {level!r}"
        );
        # And bob still cannot write the field.
        tag = _run(
            "try_field_write_then_read", args=[profile_id, "TAMPERED"], root_id=bob
        );
        assert _lines(tag, "TAG:") == ["TAG:alice_v1"] , (
            f"self-granted WRITE was honored: {tag!r}"
        );
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "grant-to-all across users emits acl_write diagnostic and the node stays closed" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run("try_perm_grant", args=[profile_id, "WRITE"], root_id=bob);
        diags = _lines(out, "DIAG:");
        assert diags == ["DIAG:acl_write:Profile:WRITE:READ"] , (
            f"expected one acl_write diagnostic at the call, got: {diags}"
        );
        level = _run("check_grant_level", args=[profile_id, bob], root_id=alice);
        assert _lines(level, "ALL:") == ["ALL:NO_ACCESS"] , (
            f"cross-user grant-to-all landed: {level!r}"
        );
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "owner grant emits no diagnostic and lands" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run("try_acl_grant", args=[profile_id, bob, "CONNECT"], root_id=alice);
        assert _lines(out, "DIAG:") == [] , f"owner grant emitted a diagnostic: {out!r}";
        level = _run("check_grant_level", args=[profile_id, bob], root_id=alice);
        assert _lines(level, "LEVEL:") == ["LEVEL:CONNECT"] , (
            f"owner grant did not land: {level!r}"
        );
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "strict mode raises PermissionError on cross-user grant" {
    _tmp = mkdtemp();
    _orig = Jac.get_base_path_dir();
    _orig_strict = Jac.strict_permissions;
    Jac.set_base_path(_tmp);
    Jac.strict_permissions = True;
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        raised = False;
        try {
            _run("try_acl_grant", args=[profile_id, bob, "WRITE"], root_id=bob);
        } except PermissionError {
            raised = True;
        }
        assert raised , "strict mode must raise PermissionError on cross-user grant";
    } finally {
        Jac.strict_permissions = _orig_strict;
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

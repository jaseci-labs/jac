"""Tests for permission-denial diagnostics (issue #5788).

Validates that cross-user write attempts (edge create, field mutation,
delete) emit a typed PermissionDenied diagnostic on the request-scoped
ExecutionContext.diagnostics list — replacing the prior silent no-op
that returned 200 OK with no signal.

Also covers the strict-mode escape hatch: when JacRuntime.strict_permissions
is True (or JAC_STRICT_PERMISSIONS env var is truthy), the runtime raises
PermissionError instead of accumulating + continuing.
"""

import io;
import os;
import sys;
import shutil;
import from pathlib { Path }
import from tempfile { mkdtemp }
import jaclang;
import from jaclang { JacRuntime as Jac }
import from jaclang.cli.commands { execution }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(JAC_ROOT, "tests", "runtimelib", "fixtures"),
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

def _run(entrypoint: str, args: list = [], `root: str = "", nd: str = "") -> str {
    captured = capture_start();
    execution.enter(
        filename=FIXTURE, entrypoint=entrypoint, args=args, **{"root": `root}, nd=nd
    );
    return capture_get(captured).strip();
}

"""Return (alice_root_id, bob_root_id, alice_profile_id) with READ grant."""
def _setup_alice_bob -> tuple[(str, str, str)] {
    alice = _run("create_other_root");
    bob = _run("create_other_root");
    profile_id = _run("create_profile", args=["alice_v1"], **{"root": alice});
    # Alice grants READ so Bob can resolve the profile by id, but neither
    # connect nor write.
    _run("grant_profile_to", args=[bob, "READ"], **{"root": alice});
    return (alice, bob, profile_id);
}

test "edge write across users emits edge_write diagnostic" {
    _tmp = mkdtemp();
    _orig = Jac.base_path_dir;
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run("try_edge_write", args=[profile_id], **{"root": bob});
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
    _orig = Jac.base_path_dir;
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run("try_field_write", args=[profile_id, "TAMPERED"], **{"root": bob});
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
        tag = _run("check_profile_tag", args=[profile_id], **{"root": alice});
        assert tag == "alice_v1" , f"expected unchanged tag, got {tag!r}";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "delete across users emits delete diagnostic and node survives" {
    _tmp = mkdtemp();
    _orig = Jac.base_path_dir;
    Jac.set_base_path(_tmp);
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        out = _run("try_delete", args=[profile_id], **{"root": bob});
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
        tag = _run("check_profile_tag", args=[profile_id], **{"root": alice});
        assert tag == "alice_v1";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "owner write does not emit diagnostic" {
    _tmp = mkdtemp();
    _orig = Jac.base_path_dir;
    Jac.set_base_path(_tmp);
    try {
        alice = _run("create_other_root");
        profile_id = _run("create_profile", args=["alice_v1"], **{"root": alice});
        out = _run(
            "try_field_write", args=[profile_id, "owner_update"], **{"root": alice}
        );
        diags = [
            line
            for line in out.split("\n")
            if line.startswith("DIAG:")
        ];
        assert len(diags) == 0 , f"owner write should not emit diagnostics, got: {diags}";
        tag = _run("check_profile_tag", args=[profile_id], **{"root": alice});
        assert tag == "owner_update";
    } finally {
        Jac.set_base_path(_orig);
        shutil.rmtree(_tmp, ignore_errors=True);
    }
}

test "strict mode raises PermissionError on cross-user edge write" {
    _tmp = mkdtemp();
    _orig = Jac.base_path_dir;
    _orig_strict = Jac.strict_permissions;
    Jac.set_base_path(_tmp);
    Jac.strict_permissions = True;
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        raised = False;
        try {
            _run("try_edge_write", args=[profile_id], **{"root": bob});
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
    _orig = Jac.base_path_dir;
    _orig_strict = Jac.strict_permissions;
    Jac.set_base_path(_tmp);
    Jac.strict_permissions = True;
    try {
        (alice, bob, profile_id) = _setup_alice_bob();
        raised = False;
        try {
            _run("try_delete", args=[profile_id], **{"root": bob});
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

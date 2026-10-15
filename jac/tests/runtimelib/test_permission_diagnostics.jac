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
import from tempfile { mkdtemp, TemporaryDirectory }
import from pathlib { Path }
import from uuid { UUID, uuid4 }
import from jaclang.runtime.archetype { AccessLevel, Root }
import from jaclang.runtime.context { ExecutionContext }
import from jaclang.runtime.runtime { JacRuntimeInterface }
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

def _run(
    entrypoint: str, args: list[any] = [], root_id: str = "", nd: str = ""
) -> str {
    captured = capture_start();
    execution.run(
        target=FIXTURE, entry_name=entrypoint, args=args, root_id=root_id, nd=nd
    );
    return capture_get(captured).strip();
}

node OrgDoc {
    has title: str = "";
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


obj OrgRoots {
    has ids: set[str];

    def __call__(rid: str) -> bool {
        return rid in self.ids;
    }
}


def _as_any(v: any) -> any {
    return v;
}


def _persisted(arch: any, owner_id: any) -> any {
    anch: any = arch.__jac__;
    anch.persistent = True;
    setattr(anch, "root", owner_id if owner_id is not None else anch.id);
    JacRuntimeInterface.get_context().mem.put(anch);
    return anch;
}


"""Apply one ACL operation to `target` and report whether it changed the target's access."""
def _acl_op(op: str, target: any, other: str, group: str) -> bool {
    arch = target.archetype;
    acc = target.own_access();
    if op == "allow_root" {
        JacRuntimeInterface.allow_root(arch, UUID(other), AccessLevel.WRITE);
        return acc.roots.anchors.get(other) == AccessLevel.WRITE;
    }
    if op == "disallow_root" {
        JacRuntimeInterface.disallow_root(arch, UUID(other));
        return other not in acc.roots.anchors;
    }
    if op == "allow_group" {
        JacRuntimeInterface.allow_group(arch, UUID(group), AccessLevel.READ);
        return acc.groups.anchors.get(group) == AccessLevel.READ;
    }
    if op == "disallow_group" {
        JacRuntimeInterface.disallow_group(arch, UUID(group));
        return group not in acc.groups.anchors;
    }
    if op == "perm_grant" {
        JacRuntimeInterface.perm_grant(arch, AccessLevel.READ);
        return acc.all == AccessLevel.READ;
    }
    JacRuntimeInterface.perm_revoke(arch);
    return acc.all == AccessLevel.NO_ACCESS;
}


test "only the system root changes access on an org root or what it owns" {
    # (op, target, caller, org resolver registered, outcome)
    ops = [
        "allow_root",
        "disallow_root",
        "allow_group",
        "disallow_group",
        "perm_grant",
        "perm_revoke"
    ];
    rows: list[tuple[str, str, str, bool, str]] = [];
    for op in ops {
        for target in ["org root", "org doc"] {
            rows.append((op, target, "outsider", True, "acl_write"));
            rows.append((op, target, "member", True, "org_acl_write"));
            rows.append((op, target, "system", True, "lands"));
        }
        rows.append((op, "org doc", "member", False, "lands"));
    }
    old_ctx = Jac.exec_ctx;
    try {
        for (op, target, caller, registered, outcome) in rows {
            label = f"{op} on {target} as {caller}"
                + ("" if registered else " (no resolver)");
            with TemporaryDirectory() as td {
                ctx = ExecutionContext(
                    base_path_dir=td, full_target_path=str(Path(td) / "org_app.jac")
                );
                Jac.exec_ctx = ctx;
                try {
                    org = _persisted(Root(), None);
                    member = _persisted(Root(), None);
                    outsider = _persisted(Root(), None);
                    doc = _persisted(OrgDoc(title="plan"), org.id);
                    other = str(uuid4());
                    group = str(uuid4());
                    org.own_access().roots.anchors[str(member.id)] = AccessLevel.WRITE;
                    tgt = org if target == "org root" else doc;
                    if op in ("disallow_root", "perm_revoke", "disallow_group") {
                        tgt.own_access().roots.anchors[other] = AccessLevel.READ;
                        tgt.own_access().groups.anchors[group] = AccessLevel.READ;
                        tgt.own_access().all = AccessLevel.READ;
                    }
                    org_key = str(org.id);
                    Jac.set_org_root_resolver(
                        OrgRoots(ids={org_key}) if registered else None
                    );
                    who = {"outsider": outsider, "member": member, "system": None};
                    ctx.set_user_root(
                        str(ctx.system_root.id)
                            if who[caller] is None
                            else str(_as_any(who[caller]).id)
                    );
                    ctx.diagnostics.clear();
                    changed = _acl_op(op, tgt, other, group);
                    ops_seen = [d.operation for d in ctx.diagnostics];
                    if outcome == "lands" {
                        assert changed , f"{label}: the change did not land";
                        assert ops_seen == [] , f"{label}: unexpected {ops_seen}";
                    } else {
                        assert not changed , f"{label}: the change landed";
                        assert ops_seen == [outcome] , (
                            f"{label}: expected [{outcome}], got {ops_seen}"
                        );
                    }
                } finally {
                    Jac.set_org_root_resolver(None);
                    Jac.exec_ctx = old_ctx;
                    ctx.close();
                }
            }
        }
    } finally {
        Jac.exec_ctx = old_ctx;
    }
}


test "a node cannot carry access rules into org ownership unless the system root saves it" {
    # (label, rule set before the save, caller, owner, resolver registered, outcome)
    rows = [
        (
            "member grants an outsider, saves under the org",
            "root",
            "member",
            "org",
            True,
            "refused"
        ),
        (
            "member opens it to all, saves under the org",
            "all",
            "member",
            "org",
            True,
            "refused"
        ),
        (
            "member grants a group, saves under the org",
            "group",
            "member",
            "org",
            True,
            "refused"
        ),
        (
            "member adds no rule, saves under the org",
            "none",
            "member",
            "org",
            True,
            "org"
        ),
        (
            "system grants an outsider, saves under the org",
            "root",
            "system",
            "org",
            True,
            "org"
        ),
        (
            "member grants an outsider, saves under the org (no resolver)",
            "root",
            "member",
            "org",
            False,
            "org"
        ),
        ("member grants an outsider, keeps it", "root", "member", "self", True, "self"),

    ];
    old_ctx = Jac.exec_ctx;
    for (label, rule, caller, owner, registered, outcome) in rows {
        with TemporaryDirectory() as td {
            ctx = ExecutionContext(
                base_path_dir=td, full_target_path=str(Path(td) / "org_app.jac")
            );
            Jac.exec_ctx = ctx;
            try {
                org = _persisted(Root(), None);
                member = _persisted(Root(), None);
                org.own_access().roots.anchors[str(member.id)] = AccessLevel.WRITE;
                org_key = str(org.id);
                Jac.set_org_root_resolver(
                    OrgRoots(ids={org_key}) if registered else None
                );
                ctx.set_user_root(
                    str(ctx.system_root.id) if caller == "system" else str(member.id)
                );
                doc = OrgDoc(title="plan");
                if rule == "root" {
                    JacRuntimeInterface.allow_root(doc, uuid4(), AccessLevel.WRITE);
                } elif rule == "all" {
                    JacRuntimeInterface.perm_grant(doc, AccessLevel.READ);
                } elif rule == "group" {
                    JacRuntimeInterface.allow_group(doc, uuid4(), AccessLevel.READ);
                }
                ctx.diagnostics.clear();
                refused = False;
                try {
                    Jac.save(doc, owner=org.id if owner == "org" else None);
                } except PermissionError {
                    refused = True;
                }
                anch: any = doc.__jac__;
                ops_seen = [d.operation for d in ctx.diagnostics];
                if outcome == "refused" {
                    assert refused , f"{label}: the save was allowed";
                    assert not anch.persistent , f"{label}: the node was persisted";
                    assert ops_seen == ["org_acl_write"] , f"{label}: got {ops_seen}";
                } else {
                    assert not refused , f"{label}: the save was refused";
                    want = org.id if outcome == "org" else ctx.user_root.id;
                    assert anch.root == want , f"{label}: owned by {anch.root}";
                    assert ops_seen == [] , f"{label}: unexpected {ops_seen}";
                }
            } finally {
                Jac.set_org_root_resolver(None);
                Jac.exec_ctx = old_ctx;
                ctx.close();
            }
        }
    }
}


test "strict mode raises PermissionError when a member changes access on org data" {
    old_ctx = Jac.exec_ctx;
    orig_strict = Jac.strict_permissions;
    with TemporaryDirectory() as td {
        ctx = ExecutionContext(
            base_path_dir=td, full_target_path=str(Path(td) / "org_app.jac")
        );
        Jac.exec_ctx = ctx;
        try {
            org = _persisted(Root(), None);
            member = _persisted(Root(), None);
            doc = _persisted(OrgDoc(title="plan"), org.id);
            org.own_access().roots.anchors[str(member.id)] = AccessLevel.WRITE;
            org_key = str(org.id);
            Jac.set_org_root_resolver(OrgRoots(ids={org_key}));
            Jac.strict_permissions = True;
            ctx.set_user_root(str(member.id));
            raised = False;
            try {
                JacRuntimeInterface.allow_root(
                    doc.archetype, uuid4(), AccessLevel.WRITE
                );
            } except PermissionError {
                raised = True;
            }
            assert raised , "strict mode must raise on a member's access change";
        } finally {
            Jac.strict_permissions = orig_strict;
            Jac.set_org_root_resolver(None);
            Jac.exec_ctx = old_ctx;
            ctx.close();
        }
    }
}

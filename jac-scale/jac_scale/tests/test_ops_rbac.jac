"""Tests for the Ops Console RBAC builder (foundation).

`build_ops_rbac` is a pure manifest builder: a namespace-scoped read-only
Role + RoleBinding bound to the gateway ServiceAccount, with mutation verbs
appended only when requested. No K8s I/O, so it's unit-tested directly.
"""

import from jac_scale.targets.kubernetes.microservice.ops_rbac {
    build_ops_rbac,
    ops_role_name
}


def _all_verbs(role: dict) -> list {
    out: list = [];
    for rule in role["rules"] {
        for v in rule["verbs"] {
            out.append(v);
        }
    }
    return out;
}


test "build_ops_rbac: read-only Role (no mutating verbs) bound to the SA" {
    out = build_ops_rbac("myapp", "myns", "myapp-sa", False);
    role = out["role"];
    binding = out["role_binding"];
    assert role["kind"] == "Role" , "namespace-scoped, not a ClusterRole";
    assert role["metadata"]["namespace"] == "myns";
    verbs = _all_verbs(role);
    assert "patch" not in verbs and "delete" not in verbs and "create" not in verbs;
    resources: list = [];
    for rule in role["rules"] {
        for res in rule["resources"] {
            resources.append(res);
        }
    }
    assert "configmaps" not in resources , "configmaps excluded (may hold secrets)";
    assert binding["subjects"][0]["name"] == "myapp-sa";
    assert binding["roleRef"]["name"] == ops_role_name("myapp");
}


test "build_ops_rbac: mutations append patch/delete verbs" {
    ro = build_ops_rbac("a", "n", "sa", False);
    mut = build_ops_rbac("a", "n", "sa", True);
    mverbs = _all_verbs(mut["role"]);
    assert "patch" in mverbs and "delete" in mverbs;
    assert len(mut["role"]["rules"]) > len(ro["role"]["rules"]) , "mutation rules are appended";
    # Empty SA falls back to the namespace `default` SA.
    assert build_ops_rbac("a", "n", "", False)["role_binding"]["subjects"][0][
        "name"
    ] == "default";
}

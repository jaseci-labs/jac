import from jaclang.scale.deploy.target.kubernetes.microservice.ops_rbac {
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
    mut_rb = build_ops_rbac("a", "n", "sa", True);
    mverbs = _all_verbs(mut_rb["role"]);
    assert "patch" in mverbs and "delete" in mverbs;
    assert len(mut_rb["role"]["rules"]) > len(ro["role"]["rules"]) , "mutation rules are appended";

    assert build_ops_rbac("a", "n", "", False)["role_binding"]["subjects"][0][
        "name"
    ] == "default";
}

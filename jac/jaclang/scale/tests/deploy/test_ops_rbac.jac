import from jaclang.scale.deploy.target.kubernetes.ops_rbac {
    build_ops_rbac,
    ops_role_name,
    ops_sa_is_ours,
    ops_sa_name
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.runtime.context.util { GATEWAY_NAME }
import from jaclang.scale.runtime.fleet { fleet_of }


def _all_verbs(role: dict[str, any]) -> list[str] {
    out: list[str] = [];
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
    resources: list[str] = [];
    for rule in role["rules"] {
        for res in rule["resources"] {
            resources.append(res);
        }
    }
    assert "configmaps" not in resources , "configmaps excluded (may hold secrets)";
    assert binding["subjects"][0]["name"] == "myapp-sa";
    assert binding["roleRef"]["name"] == ops_role_name("myapp");
    account = out["service_account"];
    assert account["kind"] == "ServiceAccount";
    assert account["metadata"]["name"] == "myapp-sa";
    assert account["metadata"]["namespace"] == "myns";
    assert account["metadata"]["labels"] == role["metadata"]["labels"] , "teardown finds it by the Role's labels";
}


test "build_ops_rbac: the read-only Role can read and watch KEDA's own resources" {
    # Without this an autoscaler runtime status cannot be read from inside a pod:
    # the ScaledObject carries the trigger and scaler conditions, and `watch` is
    # what a namespace observer needs, so granting it later means a second RBAC
    # change and a redeploy.
    role = build_ops_rbac("myapp", "myns", "myapp-sa", False)["role"];
    keda = [
        r
        for r in role["rules"]
        if "keda.sh" in r["apiGroups"]
    ];
    assert len(keda) == 1 , role["rules"];
    assert sorted(keda[0]["resources"]) == ["scaledobjects", "triggerauthentications"];
    for verb in ["get", "list", "watch"] {
        assert verb in keda[0]["verbs"] , keda[0];
    }
    assert "patch" not in keda[0]["verbs"] and "delete" not in keda[0]["verbs"];
}


test "build_ops_rbac: mutations append patch/delete verbs" {
    ro = build_ops_rbac("a", "n", "sa", False);
    mut_rb = build_ops_rbac("a", "n", "sa", True);
    mverbs = _all_verbs(mut_rb["role"]);
    assert "patch" in mverbs and "delete" in mverbs;
    assert len(mut_rb["role"]["rules"]) > len(ro["role"]["rules"]) , "mutation rules are appended";
}


test "build_ops_rbac refuses to bind the console to the namespace default account" {
    # Every pod that names no ServiceAccount runs as `default`, so a Role bound
    # there is a grant to the whole namespace, not to the console.
    for sa in ["", "default"] {
        refused = False;
        try {
            build_ops_rbac("a", "n", sa, True);
        } except ValueError {
            refused = True;
        }
        assert refused , f"bound the console Role to '{sa}'";
    }
}


def _bundle(
    ops_console: bool, service_account_name: str, app_name: str = "shop"
) -> dict[str, any] {
    import tempfile;
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as project {
        for name in ["orders_app", "main"] {
            (Path(project) / f"{name}.jac").write_text("");
        }
        builder = ManifestBuilder(
            k8s_config=KubernetesConfig(
                app_name=app_name,
                namespace="shop-ns",
                bundle_storage_class="standard",
                ops_console=ops_console,
                service_account_name=service_account_name
            ),
            fleet=fleet_of(
                {"orders_app": "/orders_app"},
                root_app="main",
                overrides={"orders_app": {"replicas": 1}}
            ),
            dry_run=True
        );
        return builder.generate_manifests(
            AppConfig(code_folder=project, app_name=app_name), ""
        );
    }
}


def _runs_as(bundle: dict[str, any], svc: str) -> (str | None) {
    pod = bundle["deployments"][svc]["spec"]["template"]["spec"];
    return pod.get("serviceAccountName");
}


test "only the gateway runs as the console's ServiceAccount, and the Role is never bound to default" {
    # (ops_console, service_account_name, gateway runs as, service runs as)
    cases = [
        (False, "", None, None),
        (False, "custom-sa", "custom-sa", "custom-sa"),
        (True, "", "shop-ops", None),
        (True, "custom-sa", "shop-ops", "custom-sa"),
        (True, "default", "shop-ops", "default")
    ];
    for (console, sa, gateway_sa, service_sa) in cases {
        bundle = _bundle(console, sa);
        label = f"ops_console={console} service_account_name={sa!r}";
        assert _runs_as(bundle, GATEWAY_NAME) == gateway_sa , label;
        assert _runs_as(bundle, "orders_app") == service_sa , label;
        if not console {
            assert "ops_rbac" not in bundle , label;
            continue;
        }
        rbac = bundle["ops_rbac"];
        assert rbac["service_account"]["metadata"]["name"] == "shop-ops" , label;
        subjects = rbac["role_binding"]["subjects"];
        assert [s["name"] for s in subjects] == ["shop-ops"] , label;
    }

    # The console's own account cannot also be the workloads' account: every
    # pod would run as it and inherit the Role.
    refused = False;
    try {
        _bundle(True, "shop-ops");
    } except ValueError {
        refused = True;
    }
    assert refused , "the console account was accepted as service_account_name";
}


test "the console's account is a valid name for any app name, and its Role keeps the app's spelling" {
    # (app_name, ServiceAccount, Role). An app name is free text. An account
    # name must be RFC 1123 and the account is applied outside the handler that
    # logs RBAC failures, so an invalid one would abort the deploy. Role and
    # RoleBinding names are path-segment names and stay as the app spelled
    # them: renaming them would leave an existing binding, and the grant it
    # holds, in place beside the new one.
    cases = [
        ("shop", "shop-ops", "shop-ops-console"),
        ("my_app", "my-app-ops", "my_app-ops-console"),
        ("MyApp", "myapp-ops", "MyApp-ops-console")
    ];
    for (app, account, role) in cases {
        assert ops_sa_name(app) == account , app;
        assert ops_role_name(app) == role , app;
        rbac = _bundle(True, "", app)["ops_rbac"];
        assert rbac["service_account"]["metadata"]["name"] == account , app;
        assert rbac["role"]["metadata"]["name"] == role , app;
        assert rbac["role_binding"]["subjects"][0]["name"] == account , app;
    }
}


test "teardown deletes the console's account only when jac-scale made it for this app" {
    ours = {"app": "shop", "managed": "jac-scale"};
    assert ops_sa_is_ours(ours, "shop");
    assert not ops_sa_is_ours(None, "shop") , "a user-created account has no labels";
    assert not ops_sa_is_ours({}, "shop");
    assert not ops_sa_is_ours({"app": "shop"}, "shop") , "not managed by jac-scale";
    assert not ops_sa_is_ours(ours, "other") , "another app's account";
}

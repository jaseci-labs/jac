import from jaclang.scale.runtime.context.util { k8s_safe_name }

glob OPS_READ_RULES: list[dict[str, any]] = [
         {
             "apiGroups": [""],
             "resources": [
                 "pods",
                 "pods/log",
                 "services",
                 "endpoints",
                 "persistentvolumeclaims",
                 "events"
             ],
             "verbs": ["get", "list", "watch"]
         },
         {
             "apiGroups": ["apps"],
             "resources": ["deployments", "replicasets", "statefulsets", "daemonsets"],
             "verbs": ["get", "list", "watch"]
         },
         {
             "apiGroups": ["autoscaling"],
             "resources": ["horizontalpodautoscalers"],
             "verbs": ["get", "list", "watch"]
         },
         {
             "apiGroups": ["keda.sh"],
             "resources": ["scaledobjects", "triggerauthentications"],
             "verbs": ["get", "list", "watch"]
         },
         {
             "apiGroups": ["networking.k8s.io"],
             "resources": ["ingresses"],
             "verbs": ["get", "list", "watch"]
         },
         {
             "apiGroups": ["policy"],
             "resources": ["poddisruptionbudgets"],
             "verbs": ["get", "list", "watch"]
         }
     ],
     OPS_MUTATE_RULES: list[dict[str, any]] = [
         {
             "apiGroups": ["apps"],
             "resources": ["deployments", "deployments/scale"],
             "verbs": ["patch", "update"]
         },
         {"apiGroups": [""], "resources": ["pods"], "verbs": ["delete"]},
         {
             "apiGroups": [""],
             "resources": ["persistentvolumeclaims"],
             "verbs": ["patch", "update"]
         },
         {
             "apiGroups": ["networking.k8s.io"],
             "resources": ["ingresses"],
             "verbs": ["patch", "update"]
         }
     ];


def ops_role_name(app_name: str) -> str {
    return f"{app_name}-ops-console";
}


def ops_sa_name(app_name: str) -> str {
    return f"{k8s_safe_name(app_name)}-ops";
}


def ops_sa_is_ours(labels: (dict[str, str] | None), app_name: str) -> bool {
    owned = labels or {};
    return owned.get("managed") == "jac-scale" and owned.get("app") == app_name;
}


def build_ops_rbac(
    app_name: str, namespace: str, sa_name: str, mutations: bool
) -> dict[str, any] {
    if not sa_name or sa_name == "default" {
        raise ValueError(
            "the Ops Console Role must be bound to a dedicated ServiceAccount, "
            f"not '{sa_name or ''}': every pod that does not name its own "
            "ServiceAccount runs as 'default' and would inherit the grant"
        );
    }
    name = ops_role_name(app_name);
    rules: list[dict[str, any]] = list(OPS_READ_RULES);
    if mutations {
        rules = rules + list(OPS_MUTATE_RULES);
    }
    labels = {"app": app_name, "managed": "jac-scale"};
    service_account = {
        "apiVersion": "v1",
        "kind": "ServiceAccount",
        "metadata": {"name": sa_name, "namespace": namespace, "labels": labels}
    };
    role = {
        "apiVersion": "rbac.authorization.k8s.io/v1",
        "kind": "Role",
        "metadata": {"name": name, "namespace": namespace, "labels": labels},
        "rules": rules
    };
    role_binding = {
        "apiVersion": "rbac.authorization.k8s.io/v1",
        "kind": "RoleBinding",
        "metadata": {"name": name, "namespace": namespace, "labels": labels},
        "roleRef": {
            "apiGroup": "rbac.authorization.k8s.io",
            "kind": "Role",
            "name": name
        },
        "subjects": [
            {"kind": "ServiceAccount", "name": sa_name, "namespace": namespace}
        ]
    };
    return {
        "service_account": service_account,
        "role": role,
        "role_binding": role_binding
    };
}

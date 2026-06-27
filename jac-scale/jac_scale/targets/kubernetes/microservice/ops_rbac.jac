glob OPS_READ_RULES: list = [
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
     OPS_MUTATE_RULES: list = [
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


def build_ops_rbac(
    app_name: str, namespace: str, sa_name: str, mutations: bool
) -> dict {
    name = ops_role_name(app_name);
    rules: list = list(OPS_READ_RULES);
    if mutations {
        rules = rules + list(OPS_MUTATE_RULES);
    }
    labels = {"app": app_name, "managed": "jac-scale"};
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
            {
                "kind": "ServiceAccount",
                "name": sa_name or "default",
                "namespace": namespace
            }
        ]
    };
    return {"role": role, "role_binding": role_binding};
}

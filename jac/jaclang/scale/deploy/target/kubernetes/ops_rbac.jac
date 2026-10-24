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


def ops_role_name(app_name: str) -> str;


def ops_sa_name(app_name: str) -> str;


def ops_sa_is_ours(labels: (dict[str, str] | None), app_name: str) -> bool;


def build_ops_rbac(
    app_name: str, namespace: str, sa_name: str, mutations: bool
) -> dict[str, any];

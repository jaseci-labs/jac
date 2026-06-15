"""Namespace-scoped RBAC for the Ops Console.

Builds a read-only Role + RoleBinding bound to the gateway's
ServiceAccount so the gateway pod can read pods / deployments / services /
endpoints / events / PVCs / ingresses through the K8s API. Namespace-scoped
(NOT a ClusterRole) so each app's gateway can only see its own
namespace, preserving per-app multi-tenancy.

Provisioned by the microservice target only when
`[plugins.scale.kubernetes].ops_console` is set; the mutation verbs
(patch/delete/scale) are appended only when
`ops_console_mutations` is also set. The ServiceAccount itself is NOT
created here - it must already exist (jacBuilder/eksctl provisions it via
`service_account_name`); when unset we bind the namespace `default` SA,
which is the SA an unconfigured pod runs as.
"""

# Read-only verbs for the deploy-health / endpoints / events / image-
# freshness pages. pods/log is included for a future tail; events surface
# OOMKilled / scheduling pressure. configmaps excluded (may hold sensitive
# config; no ops page reads them).
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
     # Mutation verbs. Deliberately narrow: patch/scale a
     # Deployment (rollout restart, force-complete, replica bump), delete a Pod
     # (force a fresh one), patch a PVC (finalizer unstick), patch an Ingress
     # (backend flip). No create/delete of Deployments/Services - redeploy goes
     # through the normal pipeline, not the API.
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


"""Shared Role/RoleBinding name for an app's Ops Console RBAC."""
def ops_role_name(app_name: str) -> str {
    return f"{app_name}-ops-console";
}


"""Build the {role, role_binding} manifest pair (plain dicts) for the Ops
Console. `mutations` appends the patch/delete/scale verbs. `sa_name`
falls back to the namespace `default` SA when empty."""
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

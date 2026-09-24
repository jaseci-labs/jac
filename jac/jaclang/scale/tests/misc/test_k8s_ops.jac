"""Direct tests for admin/k8s_ops's API accessors off-cluster.

These helpers are normally reached only transitively through the admin impls,
where k8s is unavailable. Here we drive the accessors directly with a mocked
kubernetes presence and no in-cluster service host.
"""

import os;
import from unittest.mock { patch }
import from jaclang.scale.admin { k8s_ops }


test "every api accessor degrades to None off-cluster, including the KEDA ones" {
    # The autoscaler accessors are reached from status paths that must render
    # "unavailable" rather than raise, so they have to answer like core_api.
    k8s_ops._config_loaded = False;
    k8s_ops._config_ok = False;
    with patch.object(k8s_ops, "HAS_KUBERNETES", True) {
        with patch.dict(os.environ) {
            os.environ.pop("KUBERNETES_SERVICE_HOST", None);
            for name in [
                "core_api",
                "apps_api",
                "networking_api",
                "autoscaling_api",
                "custom_objects_api"
            ] {
                assert getattr(k8s_ops, name)() is None , name;
            }
        }
    }
    k8s_ops._config_loaded = False;
    k8s_ops._config_ok = False;
}

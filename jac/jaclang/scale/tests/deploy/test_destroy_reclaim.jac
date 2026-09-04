"""Destroy branches a real cluster cannot reach (#7968).

What destroy reclaims and what it spares is decided by an API server, so those
properties are asserted in destroy_reclaim_real_e2e.sh against real objects.
Only the branches that need a cluster to misbehave live here.
"""
import unittest.mock;
import from types { SimpleNamespace }
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes { target as target_mod }
import from jaclang.scale.deploy.target.kubernetes.utils { kubernetes_utils as utils }
import from jaclang.scale.injector.pvc_injector { bundle_pvc_name }

glob APP: str = "test01",
     NS: str = "jb-test-ns",
     CO_TENANT: str = "test02";


def _pvc(name: str, role: str, owner: str = "") -> any {
    labels: dict[str, str] = {"managed": "jac-scale", "jac-scale.role": role};
    if owner {
        labels["jac-scale.owner"] = owner;
    }
    return SimpleNamespace(metadata=SimpleNamespace(name=name, labels=labels));
}


def _run_destroy(
    apps_v1: any,
    core_v1: any,
    on_delete_namespace: any,
    component: str = "",
    monitoring: any = None,
    owned: bool = True,
    logger: any = None
) {
    monitoring_deployer = unittest.mock.MagicMock();
    if monitoring is not None {
        monitoring_deployer = unittest.mock.MagicMock(return_value=monitoring);
    }
    fake_client = SimpleNamespace(
        AppsV1Api=lambda { apps_v1; },
        CoreV1Api=lambda { core_v1; },
        PolicyV1Api=lambda { unittest.mock.MagicMock(); },
        NetworkingV1Api=lambda { unittest.mock.MagicMock(); },
        RbacAuthorizationV1Api=lambda { unittest.mock.MagicMock(); }
    );
    with unittest.mock.patch.multiple(
        target_mod,
        client=fake_client,
        namespace_is_owned=unittest.mock.MagicMock(return_value=owned),
        delete_namespace=on_delete_namespace,
        KEDAAutoscaler=unittest.mock.MagicMock(),
        MonitoringDeployer=monitoring_deployer
    ) {
        with unittest.mock.patch.object(
            target_mod.KubernetesTarget,
            "_load_cluster_config",
            unittest.mock.MagicMock(return_value=None)
        ) {
            with unittest.mock.patch.object(
                target_mod.AutoscalerFactory,
                "create",
                return_value=unittest.mock.MagicMock()
            ) {
                target = target_mod.KubernetesTarget(
                    config=KubernetesConfig(app_name=APP, namespace=NS),
                    microservices_config={},
                    logger=logger
                );
                target.destroy(APP, component=component);
            }
        }
    }
}


def _co_tenant_apis -> tuple[any, any] {
    apps_v1 = unittest.mock.MagicMock();
    apps_v1.list_namespaced_stateful_set.return_value = SimpleNamespace(
        items=[SimpleNamespace(metadata=SimpleNamespace(name=f"{CO_TENANT}-postgres"))]
    );
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    core_v1.list_namespaced_persistent_volume_claim.return_value = SimpleNamespace(
        items=[]
    );
    return (apps_v1, core_v1);
}


def _warnings_naming_co_tenant(logger: any) -> list[str] {
    return [
        str(call[0][0])
        for call in logger.warning.call_args_list
        if CO_TENANT in str(call[0][0])
    ];
}


test "the default namespace is never treated as owned" {
    core_v1 = unittest.mock.MagicMock();

    assert not utils.namespace_is_owned(core_v1, "default", APP) , (
        "treating 'default' as owned would delete the cluster's default namespace"
    );
    assert not core_v1.read_namespace.called , (
        "'default' must be refused without a cluster read"
    );
}


test "a namespace with no readable labels is never owned" {
    for labels in [None, {}] {
        core_v1 = unittest.mock.MagicMock();
        core_v1.read_namespace.return_value = SimpleNamespace(
            metadata=SimpleNamespace(labels=labels)
        );
        assert not utils.namespace_is_owned(core_v1, NS, APP) , (
            f"a namespace whose labels read as {labels} was treated as owned, "
            "so destroy would delete a namespace it cannot prove it created"
        );
    }
}


test "an unreachable cluster fails loudly instead of reading as adopted" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespace.side_effect = ApiException(status=503);
    raised = False;

    try {
        utils.namespace_is_owned(core_v1, NS, APP);
    } except ApiException {
        raised = True;
    }

    assert raised , (
        "answering 'not owned' when the cluster is unreachable silently skips "
        "the reclaim and brings the #7968 leak back"
    );
}


test "a missing namespace is not owned" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespace.side_effect = ApiException(status=404);

    assert not utils.namespace_is_owned(core_v1, NS, APP) , (
        "a namespace that is already gone has nothing left to reclaim"
    );
}


test "a failed monitoring teardown keeps the namespace" {
    deleted_namespaces: list = [];
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    monitoring = unittest.mock.MagicMock();
    monitoring.destroy.side_effect = RuntimeError("prometheus ClusterRole stuck");

    _run_destroy(
        unittest.mock.MagicMock(),
        core_v1,
        deleted_namespaces.append,
        monitoring=monitoring
    );

    assert not deleted_namespaces , (
        "the namespace was deleted after monitoring teardown failed, orphaning "
        "cluster-scoped roles named after a namespace that no longer exists"
    );
}


test "a namespace this app created but no longer holds alone is kept" {
    deleted_namespaces: list = [];
    apps_v1 = unittest.mock.MagicMock();
    apps_v1.list_namespaced_stateful_set.return_value = SimpleNamespace(
        items=[SimpleNamespace(metadata=SimpleNamespace(name=f"{CO_TENANT}-postgres"))]
    );
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    core_v1.read_namespace.side_effect = ApiException(status=404);
    core_v1.list_namespaced_persistent_volume_claim.return_value = SimpleNamespace(
        items=[_pvc(bundle_pvc_name(CO_TENANT), "bundle-store")]
    );

    _run_destroy(apps_v1, core_v1, deleted_namespaces.append);

    assert not deleted_namespaces , (
        f"the namespace was deleted whole while '{CO_TENANT}' was still "
        "deployed into it, taking that app's database and volumes with it"
    );
    assert apps_v1.delete_namespaced_stateful_set.called , (
        "the shared-namespace path did not run, so this app's own database "
        "was left behind instead"
    );
}


test "a namespace this app created and holds alone is still reclaimed" {
    deleted_namespaces: list = [];
    apps_v1 = unittest.mock.MagicMock();
    apps_v1.list_namespaced_stateful_set.return_value = SimpleNamespace(
        items=[SimpleNamespace(metadata=SimpleNamespace(name=f"{APP}-postgres"))]
    );
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    core_v1.read_namespace.side_effect = ApiException(status=404);
    core_v1.list_namespaced_persistent_volume_claim.return_value = SimpleNamespace(
        items=[
            _pvc(bundle_pvc_name(APP), "bundle-store"),
            _pvc("uploads", "shared-volume", APP)
        ]
    );

    _run_destroy(apps_v1, core_v1, deleted_namespaces.append);

    assert deleted_namespaces == [NS] , (
        "this app's own resources read as a co-tenant's, so the namespace it "
        "created leaks with everything in it (#7968)"
    );
}


test "destroying the database keeps the volume holding the app's code" {
    core_v1 = unittest.mock.MagicMock();

    _run_destroy(
        unittest.mock.MagicMock(),
        core_v1,
        unittest.mock.MagicMock(),
        component="database"
    );

    deleted: list = [
        call.args[0]
        for call in core_v1.delete_namespaced_persistent_volume_claim.call_args_list
    ];
    assert bundle_pvc_name(APP) not in deleted , (
        "tearing down the database deleted the bundle volume the still-running "
        "app pods mount"
    );
    assert f"{APP}-postgres-data-{APP}-postgres-0" in deleted , (
        "the postgres data volume outlived the database it belongs to"
    );
}


test "an app on an external database loses its connection-string secret" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    core_v1.read_namespace.side_effect = ApiException(status=404);
    core_v1.list_namespaced_persistent_volume_claim.return_value = SimpleNamespace(
        items=[_pvc(bundle_pvc_name(CO_TENANT), "bundle-store")]
    );

    _run_destroy(unittest.mock.MagicMock(), core_v1, unittest.mock.MagicMock());

    deleted: list = [
        call.kwargs.get("name")
        for call in core_v1.delete_namespaced_secret.call_args_list
    ];
    assert f"{APP}-external-db" in deleted , (
        "the secret holding the external database connection string stayed in "
        "a namespace this destroy does not reclaim"
    );
}


test "removing the application names the co-tenant whose workloads went too" {
    (apps_v1, core_v1) = _co_tenant_apis();
    logger = unittest.mock.MagicMock();

    _run_destroy(
        apps_v1,
        core_v1,
        unittest.mock.MagicMock(),
        component="application",
        logger=logger
    );

    assert _warnings_naming_co_tenant(logger) , (
        f"'{CO_TENANT}' lost its deployments, autoscalers and disruption "
        "budgets to the namespace-wide sweep without a word, so nobody knows "
        "to redeploy it"
    );
}


test "a namespace holding no other app warns about no co-tenant" {
    apps_v1 = unittest.mock.MagicMock();
    apps_v1.list_namespaced_stateful_set.return_value = SimpleNamespace(
        items=[SimpleNamespace(metadata=SimpleNamespace(name=f"{APP}-postgres"))]
    );
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    core_v1.list_namespaced_persistent_volume_claim.return_value = SimpleNamespace(
        items=[]
    );
    logger = unittest.mock.MagicMock();

    _run_destroy(
        apps_v1,
        core_v1,
        unittest.mock.MagicMock(),
        component="application",
        logger=logger
    );

    assert not _warnings_naming_co_tenant(logger) , (
        "this app's own database read as another app's, so a solo deployment "
        "is told to redeploy an app that does not exist"
    );
}


test "a refused monitoring teardown fails its own component destroy" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    monitoring = unittest.mock.MagicMock();
    monitoring.destroy.side_effect = ApiException(status=403);

    raised = False;
    try {
        _run_destroy(
            unittest.mock.MagicMock(),
            core_v1,
            unittest.mock.MagicMock(),
            component="monitoring",
            monitoring=monitoring
        );
    } except ApiException {
        raised = True;
    }

    assert raised , (
        "destroying the monitoring component reported success while its "
        "cluster-scoped roles were refused, so nobody knows to retry"
    );
}


def _refuse_namespace_delete(name: str) {
    raise ApiException(status=403);
}


test "a namespace this app may not delete still gives up its database" {
    apps_v1 = unittest.mock.MagicMock();
    apps_v1.list_namespaced_stateful_set.return_value = SimpleNamespace(
        items=[SimpleNamespace(metadata=SimpleNamespace(name=f"{APP}-postgres"))]
    );
    core_v1 = unittest.mock.MagicMock();
    core_v1.list_namespaced_service.return_value = SimpleNamespace(items=[]);
    core_v1.list_namespaced_persistent_volume_claim.return_value = SimpleNamespace(
        items=[_pvc(bundle_pvc_name(APP), "bundle-store")]
    );

    _run_destroy(apps_v1, core_v1, _refuse_namespace_delete);

    assert apps_v1.delete_namespaced_stateful_set.called , (
        "the namespace delete was refused and destroy gave up there, so the "
        "database and its volume stay with no way to reclaim them by re-running"
    );
}

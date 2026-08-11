import from types { SimpleNamespace }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.deploy.target.kubernetes.target { KubernetesTarget }

# A Deployment as a pre-0.34.9 toolchain wrote it: bare app name, no role label,
# and the same pod selector the current one uses.
def _legacy_deployment(app: str) -> any {
    return SimpleNamespace(
        metadata=SimpleNamespace(name=app, labels={"app": app, "managed": "jac-scale"}),
        spec=SimpleNamespace(selector=SimpleNamespace(match_labels={"app": app}))
    );
}


def _current_deployment(app: str) -> any {
    return SimpleNamespace(
        metadata=SimpleNamespace(
            name=f"{app}-deployment",
            labels={
                "app": app,
                "managed": "jac-scale",
                "jac-scale.role": "microservice"
            }
        ),
        spec=SimpleNamespace(selector=SimpleNamespace(match_labels={"app": app}))
    );
}


# A companion jac-scale owns but must never reap: same namespace, same owner
# label, different selector.
def _provisioned_postgres(app: str) -> any {
    name = f"{app}-postgres";
    return SimpleNamespace(
        metadata=SimpleNamespace(
            name=name, labels={"app": name, "managed": "jac-scale"}
        ),
        spec=SimpleNamespace(selector=SimpleNamespace(match_labels={"app": name}))
    );
}


# A Deployment on the same selector that jac-scale did NOT create; deleting an
# operator's own object would be worse than the split it prevents.
def _hand_rolled_canary(app: str) -> any {
    return SimpleNamespace(
        metadata=SimpleNamespace(name=f"{app}-canary", labels={"app": app}),
        spec=SimpleNamespace(selector=SimpleNamespace(match_labels={"app": app}))
    );
}


obj FakeAppsV1 {
    has items: list,
        deleted: list = [];

    def list_namespaced_deployment(namespace: str, **kwargs: any) -> any {
        return SimpleNamespace(items=list(self.items));
    }

    def delete_namespaced_deployment(name: str, namespace: str, **kwargs: any) {
        self.deleted.append(name);
    }
}


def _target(app: str = "standup", namespace: str = "standup") -> KubernetesTarget {
    return KubernetesTarget(
        config=KubernetesConfig(app_name=app, namespace=namespace),
        microservices_config={}
    );
}


def _bundle_for(app: str) -> dict[str, any] {
    builder = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name=app, namespace=app),
        microservices_config={}
    );
    specs = builder.generate_service_pod_specs(
        AppConfig(code_folder=f"/apps/{app}", file_name="main.jac"), "img"
    );
    deployments: dict[str, any] = {};
    services: dict[str, any] = {};
    for svc_name in specs.keys() {
        deployments[svc_name] = builder._build_deployment_manifest(svc_name, {});
        services[svc_name] = builder._build_service_manifest(svc_name);
    }
    return {"deployments": deployments, "services": services};
}


test "a bundle never ships two Deployments backing one Service selector" {
    bundle = _bundle_for("standup");

    by_selector: dict[str, list] = {};
    for dep in bundle["deployments"].values() {
        selector = dep["spec"]["selector"]["matchLabels"]["app"];
        by_selector.setdefault(selector, []).append(dep["metadata"]["name"]);
    }

    for svc in bundle["services"].values() {
        selector = svc["spec"]["selector"]["app"];
        backing = by_selector.get(selector, []);
        assert len(backing) == 1 , f"Service {svc['metadata']['name']} is backed by {len(
            backing
        )} "
        f"Deployments in one bundle: {backing}";
    }
}


test "the superseded pre-0.34.9 Deployment is reaped on upgrade" {
    apps_v1 = FakeAppsV1(items=[_legacy_deployment("standup")]);

    _target().reap_superseded_deployments(apps_v1, "standup", _bundle_for("standup"));

    assert apps_v1.deleted == ["standup"] , f"expected the pre-0.34.9 Deployment to be reaped, deleted={apps_v1.deleted}";
}


test "the Deployment we just applied is never reaped" {
    apps_v1 = FakeAppsV1(items=[_current_deployment("standup")]);

    _target().reap_superseded_deployments(apps_v1, "standup", _bundle_for("standup"));

    assert apps_v1.deleted == [] , f"the current Deployment must survive its own apply, deleted={apps_v1.deleted}";
}


test "a provisioned database on another selector is never reaped" {
    apps_v1 = FakeAppsV1(
        items=[_current_deployment("standup"), _provisioned_postgres("standup")]
    );

    _target().reap_superseded_deployments(apps_v1, "standup", _bundle_for("standup"));

    assert apps_v1.deleted == [] , f"jac-scale companions must survive, deleted={apps_v1.deleted}";
}


test "a Deployment jac-scale does not own is never reaped" {
    apps_v1 = FakeAppsV1(
        items=[_current_deployment("standup"), _hand_rolled_canary("standup")]
    );

    _target().reap_superseded_deployments(apps_v1, "standup", _bundle_for("standup"));

    assert apps_v1.deleted == [] , f"an unowned Deployment must never be deleted, deleted={apps_v1.deleted}";
}


# The reap keys off the Service selector rather than the absence of a role
# label, so it holds for a rename in either direction, not just this one.
test "a future rename is reaped from either direction" {
    renamed = _current_deployment("standup");
    renamed.metadata.name = "standup-app";
    apps_v1 = FakeAppsV1(items=[renamed]);

    _target().reap_superseded_deployments(apps_v1, "standup", _bundle_for("standup"));

    assert apps_v1.deleted == ["standup-app"] , f"a renamed owned Deployment on our selector must be reaped, "
    f"deleted={apps_v1.deleted}";
}


test "reaping survives a cluster that cannot list Deployments" {
    obj BrokenAppsV1 {
        def list_namespaced_deployment(namespace: str, **kwargs: any) -> any {
            raise RuntimeError("apiserver unavailable");
        }
    }

    # A cleanup failure must not fail an otherwise healthy deploy.
    _target().reap_superseded_deployments(
        BrokenAppsV1(), "standup", _bundle_for("standup")
    );
}

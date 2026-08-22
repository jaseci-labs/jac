import from types { SimpleNamespace }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.deploy.target.kubernetes.target {
    KubernetesTarget,
    restorable_pod_template,
    app_bundle_digest,
    releases_from_revisions,
    fleet_targets_for_release,
    fleet_revert_order,
    deployment_rollout_complete
}

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


# Revision based rollback (#8089). Selecting which ReplicaSet backs a revision
# is the decision worth testing; the patch call around it is a single client
# call. A ReplicaSet is keyed by its owning Deployment because a fleet reverts
# per Deployment, and one with no owner is not ours to revert.
def _replica_set(deployment: str, revision: str, owned: bool = True) -> any {
    return SimpleNamespace(
        metadata=SimpleNamespace(
            name=f"{deployment}-{revision}",
            annotations={"deployment.kubernetes.io/revision": revision},
            owner_references=([SimpleNamespace(name=deployment)] if owned else [])
        )
    );
}


# pod-template-hash is stamped by the ReplicaSet controller. Reverting a
# template that still carries it pins the new ReplicaSet to the old hash, so
# the controller cannot own the pods it creates.
test "reverting a template drops pod-template-hash and keeps the rest" {
    cleaned = restorable_pod_template(
        {
            "metadata": {
                "labels": {
                    "app": "orders",
                    "managed": "jac-scale",
                    "pod-template-hash": "76785c59cb"
                }
            },
            "spec": {"containers": []}
        }
    );

    labels = cleaned["metadata"]["labels"];
    assert "pod-template-hash" not in labels;
    assert labels == {"app": "orders", "managed": "jac-scale"};
    assert cleaned["spec"] == {"containers": []};
}


# App scoping. `managed=jac-scale` marks the product, not the app, and two apps
# can share a namespace. Kubernetes revision numbers are per Deployment and
# overlap freely, so an unscoped revert would patch a neighbour's fleet.
obj _FleetApps {
    has names: list,
        selector: str = "";

    def list_namespaced_deployment(namespace: str, **kwargs: any) -> any {
        self.selector = str(kwargs.get("label_selector", ""));
        return SimpleNamespace(
            items=[
                SimpleNamespace(metadata=SimpleNamespace(name=n)) for n in self.names
            ]
        );
    }
}


# ScaleClient hands every lifecycle call a bare DeploySpec, and
# to_microservices_config() always returns a dict carrying a `routes` key, so
# _ms_cfg short-circuits on it and never falls back to jac.toml. Deriving the
# fleet from those empty routes resolved `{app}-deployment` plus the gateway --
# a Deployment that does not exist for a microservice app, and one that is a
# fraction of the set. rollback() refused every time and revisions() reported
# the gateway alone.
test "the fleet is read from the cluster, not from a route table" {
    target = KubernetesTarget(
        config=KubernetesConfig(app_name="shop", namespace="shop"),
        microservices_config={"routes": {}}
    );
    api = _FleetApps(
        names=["orders-app-deployment", "gateway-deployment", "cart-app-deployment"]
    );

    names = target._fleet_deployment_names(api, "shop");

    assert names
        == ["cart-app-deployment", "orders-app-deployment", "gateway-deployment"] , (
        f"the real fleet, gateway last: {names}"
    );
    assert api.selector
        == "managed=jac-scale,jac-scale.role in (microservice,gateway)" , (
        "the fleet must be scoped exactly as destroy scopes it, or a rollback "
        "reaches objects the app does not own"
    );
}


# The gateway fronts the fleet, so restoring it before the services it routes to
# serves the restored frontend against services still on the release being left.
# rollback_to patches in this order, so the order is the guarantee.
test "the revert order puts the gateway last whatever the cluster returns" {
    assert fleet_revert_order(
        ["gateway-deployment", "orders-app-deployment", "cart-app-deployment"]
    )
        == ["cart-app-deployment", "orders-app-deployment", "gateway-deployment"];
}


test "a fleet with no gateway is still ordered and complete" {
    assert fleet_revert_order(["b-deployment", "a-deployment"])
        == ["a-deployment", "b-deployment"];
}


test "an unreadable cluster resolves no fleet rather than a wrong one" {
    obj_target = KubernetesTarget(
        config=KubernetesConfig(app_name="shop", namespace="shop"),
        microservices_config={"routes": {}}
    );

    assert obj_target._fleet_deployment_names(_BrokenFleetApps(), "shop") == [];
}


# A release is a bundle digest, not a revision number: a service whose pod
# template did not change gets no new revision, so the fleet drifts apart and
# "revision 2" means different releases for different services.
test "a release groups the revisions that share a bundle digest" {
    releases = releases_from_revisions(
        [
            {
                "deployment": "orders-app-deployment",
                "revision": 4,
                "bundle_digest": "aaa",
                "created": "t4"
            },
            {
                "deployment": "gateway-deployment",
                "revision": 2,
                "bundle_digest": "aaa",
                "created": "t2"
            },
            {
                "deployment": "orders-app-deployment",
                "revision": 3,
                "bundle_digest": "bbb",
                "created": "t3"
            }
        ]
    );

    assert len(releases) == 2;
    assert releases[0]["bundle_digest"] == "aaa";
    assert releases[0]["deployments"]
        == {"orders-app-deployment": 4, "gateway-deployment": 2} , "a release spans every service that shipped it, at whatever revision each took";
}


test "the app bundle digest is read from the app bundle, not the toolchain" {
    assert app_bundle_digest(["toolchain/shop/ccc.tar.gz", "bundles/shop/aaa.jab"])
        == "aaa";
    assert app_bundle_digest(["toolchain/shop/ccc.tar.gz"]) == "";
}


# The blocker this guards: a fleet where one service has no retained revision
# for the target release must refuse, not revert the rest and report success.
test "a release missing a fleet member refuses rather than half reverting" {
    releases = releases_from_revisions(
        [
            {
                "deployment": "orders-app-deployment",
                "revision": 2,
                "bundle_digest": "aaa",
                "created": "t"
            }
        ]
    );

    out = fleet_targets_for_release(
        releases, 2, ["orders-app-deployment", "gateway-deployment"]
    );

    assert not out["ok"];
    assert out["missing"] == ["gateway-deployment"];
    assert out["targets"] == {} , "nothing may be patched when the fleet cannot fully revert";
}


test "a complete release resolves every member's own revision" {
    releases = releases_from_revisions(
        [
            {
                "deployment": "orders-app-deployment",
                "revision": 4,
                "bundle_digest": "aaa",
                "created": "t"
            },
            {
                "deployment": "gateway-deployment",
                "revision": 2,
                "bundle_digest": "aaa",
                "created": "t"
            }
        ]
    );

    out = fleet_targets_for_release(
        releases, 4, ["orders-app-deployment", "gateway-deployment"]
    );

    assert out["ok"];
    assert out["targets"] == {"orders-app-deployment": 4, "gateway-deployment": 2} , "each service reverts to the revision that carried this release, not to 4";
}


# A release is the code bundle. A config-only deploy leaves the bundle digest
# unchanged, so it folds into the release it shares a bundle with rather than
# appearing as a rollback target of its own: reverting a pod template restores
# code, and the Secret it reads is always the current one.
test "a config-only redeploy is not a rollback target of its own" {
    releases = releases_from_revisions(
        [
            {
                "deployment": "orders-app-deployment",
                "revision": 1,
                "bundle_digest": "aaa",
                "created": "t1"
            },
            {
                "deployment": "orders-app-deployment",
                "revision": 2,
                "bundle_digest": "aaa",
                "created": "t2"
            }
        ]
    );

    assert len(releases) == 1 , (
        f"same bundle is one release whatever config it ran with; got {len(releases)}"
    );
    assert releases[0]["revision"] == 2 , "the newest revision carries the release";
}


test "the same code and config stays one release across services" {
    releases = releases_from_revisions(
        [
            {
                "deployment": "orders-app-deployment",
                "revision": 4,
                "bundle_digest": "aaa",
                "created": "t"
            },
            {
                "deployment": "gateway-deployment",
                "revision": 2,
                "bundle_digest": "aaa",
                "created": "t"
            }
        ]
    );

    assert len(releases) == 1;
    assert releases[0]["deployments"]
        == {"orders-app-deployment": 4, "gateway-deployment": 2};
}


def _rollout(
    generation: int,
    observed: int,
    replicas: int,
    updated: int,
    available: int,
    desired: int = 1
) -> any {
    return SimpleNamespace(
        metadata=SimpleNamespace(generation=generation),
        spec=SimpleNamespace(replicas=desired),
        status=SimpleNamespace(
            observed_generation=observed,
            replicas=replicas,
            updated_replicas=updated,
            available_replicas=available
        )
    );
}


# The rollout waiter used to accept "at least one ready replica". Immediately
# after a pod template is patched the OLD pods are still ready, so it returned
# success before the reverted template had rolled out at all, and a revert that
# never started -- or crash-looped once it did -- still reported success.
test "a rollout is not complete while the old pods are the ready ones" {
    assert not deployment_rollout_complete(
        _rollout(generation=2, observed=1, replicas=1, updated=0, available=1)
    ) , "the controller has not observed the patch yet";
    assert not deployment_rollout_complete(
        _rollout(generation=2, observed=2, replicas=1, updated=0, available=1)
    ) , "no replica runs the reverted template yet";
    assert not deployment_rollout_complete(
        _rollout(generation=2, observed=2, replicas=2, updated=1, available=1)
    ) , "an old replica is still serving beside the reverted one";
    assert not deployment_rollout_complete(
        _rollout(generation=2, observed=2, replicas=1, updated=1, available=0)
    ) , "the reverted pod exists but has not become available";
}


test "a rollout is complete once every replica runs the new template" {
    assert deployment_rollout_complete(
        _rollout(generation=2, observed=2, replicas=1, updated=1, available=1)
    );
    assert deployment_rollout_complete(
        _rollout(
            generation=3, observed=3, replicas=3, updated=3, available=3, desired=3
        )
    );
    assert not deployment_rollout_complete(
        _rollout(
            generation=3, observed=3, replicas=2, updated=2, available=2, desired=3
        )
    ) , "a three replica service is not rolled out on two";
}


# ReplicaSet list order is not guaranteed by the API. Keying a release on the
# bundle digest alone puts every revision of a deployment that shipped that
# bundle into one release, so taking the last one seen would let the API report
# release revision 2 while rolling that service back to revision 1.
# A revert replaces /spec/template wholesale, so the retained template brings
# its own jac-scale.config-revision back with it. The pods come up reading the
# CURRENT Secret, which is the stated intent, so a marker naming an older config
# generation is simply false, and the next deploy reads it as a config change
# and rolls the whole fleet for nothing. Same shape as the controller's own
# pod-template-hash: a field the restored template must not carry back.
test "a restored template drops the config marker it was stamped with" {
    cleaned = restorable_pod_template(
        {
            "metadata": {
                "labels": {"app": "orders", "pod-template-hash": "abc123"},
                "annotations": {"jac-scale.config-revision": "1001", "team": "ops"}
            }
        }
    );

    assert "pod-template-hash" not in cleaned["metadata"]["labels"];
    assert "jac-scale.config-revision" not in cleaned["metadata"]["annotations"] , (
        "the restored template claims a config generation its pods are not "
        "running, and the next deploy rolls the fleet over the difference"
    );
    assert cleaned["metadata"]["annotations"]["team"] == "ops" , (
        "unrelated annotations belong to the release and must survive"
    );
}


test "a restored template with only the config marker keeps no empty annotations" {
    cleaned = restorable_pod_template(
        {"metadata": {"annotations": {"jac-scale.config-revision": "1001"}}}
    );

    assert "annotations" not in cleaned["metadata"];
}


test "a release holds the newest revision of each service, whatever the order" {
    entries = [
        {
            "deployment": "orders-app-deployment",
            "revision": 1,
            "bundle_digest": "aaa",
            "created": "t1"
        },
        {
            "deployment": "orders-app-deployment",
            "revision": 2,
            "bundle_digest": "aaa",
            "created": "t2"
        }
    ];

    for ordered in [entries, list(reversed(entries))] {
        release = releases_from_revisions(ordered)[0];
        assert release["deployments"] == {"orders-app-deployment": 2} , (
            "the release restores the newest revision that carried its bundle, "
            "not whichever the API happened to list last"
        );
        assert release["revision"] == 2;
    }
}


obj _HalfPatchApps {
    has fail_on: str,
        patched: list = [];

    def read_namespaced_deployment(name: str, namespace: str) -> any {
        return SimpleNamespace(
            spec=SimpleNamespace(
                template={"metadata": {"labels": {}}, "spec": {"live": name}}
            )
        );
    }

    def patch_namespaced_deployment(name: str, namespace: str, body: any) -> any {
        value = body[0]["value"];
        if name == self.fail_on and "live" not in dict(value.get("spec") or {}) {
            raise RuntimeError("apiserver rejected the patch");
        }
        self.patched.append((name, dict(value.get("spec") or {}).get("live", "old")));
        return None;
    }
}


# Resolving every target up front stops a rollback that could never complete,
# but the patches still land one at a time. A failure halfway used to leave the
# already reverted services on the old release while the rest served the new
# one: the split this feature exists to prevent.
test "a rollback that fails halfway puts the reverted services back" {
    target = _target(app="orders", namespace="orders");
    api = _HalfPatchApps(fail_on="gateway-deployment");

    stranded = target._restore_templates(
        api,
        "orders",
        ["orders-app-deployment"],
        {"orders-app-deployment": {"spec": {"live": "orders-app-deployment"}}}
    );

    assert stranded == [] , "the reverted deployment must be put back";
    assert api.patched == [("orders-app-deployment", "orders-app-deployment")];
}


test "a compensation that also fails names what is left split" {
    target = _target(app="orders", namespace="orders");
    api = _HalfPatchApps(fail_on="orders-app-deployment");

    stranded = target._restore_templates(
        api, "orders", ["orders-app-deployment"], {"orders-app-deployment": {}}
    );

    assert stranded == ["orders-app-deployment"] , (
        "an operator has to be told which services are still on the old release"
    );
}


# The revision API is scoped by the target's own config, not by the argument,
# so passing another app's name used to return THIS app's revisions with no
# complaint, and rollback_to would revert this app while reporting the other.
test "the revision API refuses an app it was not built for" {
    target = _target(app="orders", namespace="shared");
    raised = False;

    try {
        target.list_revisions("billing");
    } except ValueError as e {
        raised = True;
        assert "orders" in str(e) and "billing" in str(e);
    }

    assert raised , "another app's name must be refused, not silently ignored";
}


test "the revision API accepts its own app and an unnamed caller" {
    target = _target(app="orders", namespace="shared");

    target._assert_own_app("orders");
    target._assert_own_app("");
}


obj _BrokenFleetApps {
    def list_namespaced_deployment(namespace: str, **kwargs: any) -> any {
        raise RuntimeError("apiserver unavailable");
    }
}


# --- rollback_to, end to end ------------------------------------------------
# Findings 1 and 4 both lived inside this function and neither was reachable
# from a test: the fleet it reverts came from a route table ScaleClient never
# fills, and the undo capture it took to compensate a half-applied revert was
# stripped of the marker that makes putting it back a no-op.

obj _RollbackApps {
    has revisions: dict,
        fail_on: str = "",
        patched: list = [],
        bodies: list = [],
        reads: list = [];

    def list_namespaced_deployment(namespace: str, **kwargs: any) -> any {
        return SimpleNamespace(
            items=[
                SimpleNamespace(metadata=SimpleNamespace(name=n))
                for n in self.revisions.keys()
            ]
        );
    }

    def list_namespaced_replica_set(namespace: str, **kwargs: any) -> any {
        items: list = [];
        for (dep, revs) in self.revisions.items() {
            for rev in revs {
                items.append(_rs_for(dep, rev));
            }
        }
        return SimpleNamespace(items=items);
    }

    def read_namespaced_deployment(name: str, namespace: str) -> any {
        self.reads.append(name);
        return SimpleNamespace(
            spec=SimpleNamespace(
                template={
                    "metadata": {
                        "labels": {"app": name, "pod-template-hash": "live"},
                        "annotations": {"jac-scale.config-revision": "cfg-live"}
                    },
                    "spec": {"live": name}
                },
                selector={"matchLabels": {"app": name}}
            )
        );
    }

    def patch_namespaced_deployment(name: str, namespace: str, body: any) -> any {
        value = body[0]["value"];
        # The revert patch carries the OLD ReplicaSet's template; the
        # compensating one carries the live template this fake hands back, which
        # is how a restore is told apart from a revert here.
        is_restore = dict(dict(value).get("spec") or {}).get("live") == name;
        if name == self.fail_on and not is_restore {
            raise RuntimeError("apiserver rejected the patch");
        }
        self.patched.append(name);
        self.bodies.append((name, dict(value)));
        return None;
    }
}


def _rs_for(deployment: str, revision: int) -> any {
    digest = "old" if revision == 1 else "new";
    return SimpleNamespace(
        metadata=SimpleNamespace(
            name=f"{deployment}-{revision}",
            annotations={"deployment.kubernetes.io/revision": str(revision)},
            owner_references=[SimpleNamespace(name=deployment)],
            creation_timestamp=None
        ),
        spec=SimpleNamespace(
            replicas=1,
            template=SimpleNamespace(
                spec={
                    "initContainers": [
                        {
                            "name": "jac-pvc-bootstrap",
                            "args": [f"/jac-bundles/bundles/app/{digest}.jab"]
                        }
                    ]
                }
            )
        )
    );
}


import unittest.mock;
import jaclang.scale.deploy.target.kubernetes.target as target_mod;


# Stands in for ApiClient.sanitize_for_serialization, which turns a kubernetes
# model into plain dicts. The fixtures are SimpleNamespaces for the same reason
# the rest of this file uses them, so the stand-in has to do the same flattening
# or rollback_to reads a namespace where the real one reads a dict.
obj _Serializer {
    def sanitize_for_serialization(value: any) -> any {
        if isinstance(value, SimpleNamespace) {
            out: dict = {};
            for (key, item) in vars(value).items() {
                out[key] = self.sanitize_for_serialization(item);
            }
            return out;
        }
        return value;
    }
}


obj _FakeClient {
    has apps: any;

    def AppsV1Api -> any {
        return self.apps;
    }

    def ApiClient -> any {
        return _Serializer();
    }
}


"""Drive rollback_to against a fake cluster.

Three stand-ins: the kubernetes client the function builds, the kubeconfig load,
and the post-revert rollout wait. The wait polls a live cluster on a sleep loop
and has its own tests (deployment_rollout_complete above); what these exercise is
which Deployments a revert touches and in what order."""
def _rollback_with(api: any) -> any {
    with unittest.mock.patch.object(target_mod, "client", _FakeClient(apps=api)) {
        with unittest.mock.patch.object(
            target_mod.KubernetesTarget, "_wait_for_fleet_rollout", return_value=None
        ) {
            with unittest.mock.patch.object(
                target_mod.KubernetesTarget, "_load_cluster_config", return_value=None
            ) {
                t = target_mod.KubernetesTarget(
                    config=KubernetesConfig(app_name="shop", namespace="shop"),
                    microservices_config={"routes": {}}
                );
                return t.rollback_to("shop", 1);
            }
        }
    }
}


# The whole point of the feature, and until now unreachable from a test: a
# microservice app rolls its ENTIRE fleet back, in an order that never fronts
# restored services with a stale gateway.
test "a rollback reverts the whole microservice fleet, gateway last" {
    api = _RollbackApps(
        revisions={
            "orders-app-deployment": [1, 2],
            "cart-app-deployment": [1, 2],
            "gateway-deployment": [1, 2]
        }
    );

    res = _rollback_with(api);

    assert res.success , res.message;
    assert api.patched
        == ["cart-app-deployment", "orders-app-deployment", "gateway-deployment"] , f"the fleet reverts services first and the gateway last: {api.patched}";
}


"""Drive a rollback whose patch fails on `fail_on`, so the compensating restore
runs and its captured template can be inspected."""
def _rollback_failing_on(name: str) -> any {
    api = _RollbackApps(
        revisions={
            "cart-app-deployment": [1, 2],
            "orders-app-deployment": [1, 2],
            "gateway-deployment": [1, 2]
        },
        fail_on=name
    );
    return (_rollback_with(api), api);
}


# The undo capture is the template that is ALREADY live, so putting it back has
# to be a no-op. Running it through restorable_pod_template stripped the current
# jac-scale.config-revision, which turned the compensation into a real template
# change: a failed rollback rolled the restored services once for nothing, and
# the next deploy rolled them again to restamp the marker.
test "a compensating restore puts back the marker the live template carried" {
    (res, api) = _rollback_failing_on("orders-app-deployment");

    assert not res.success , "the patch was rejected, so the rollback failed";
    restores = [
        b
        for b in api.bodies
        if dict(b[1].get("spec") or {}).get("live")
    ];
    assert restores , "the reverted service must be put back";
    (name, body) = restores[0];
    marker = dict(dict(body.get("metadata") or {}).get("annotations") or {}).get(
        "jac-scale.config-revision"
    );
    assert marker == "cfg-live" , (
        f"the restore dropped the live config marker ({marker}), so putting the "
        "template back is a template CHANGE and rolls the service for nothing"
    );
}


obj _UnreadableApps {
    def list_namespaced_deployment(namespace: str, **kwargs: any) -> any {
        return SimpleNamespace(items=[]);
    }

    def list_namespaced_replica_set(namespace: str, **kwargs: any) -> any {
        raise RuntimeError("replicasets is forbidden: RBAC");
    }
}


# The retention contract is "a bundle a retained revision references is never
# deleted". An unreadable cluster returning an empty keep-set is that contract
# inverted: a pruner reads it as "nothing is referenced" and deletes every
# bundle the app owns, including the one its live pods mount. list_revisions
# stays lenient -- an empty history costs a rollback, not the app.
test "the retention keep-set refuses to answer from an unreadable cluster" {
    api = _UnreadableApps();
    raised = False;

    with unittest.mock.patch.object(target_mod, "client", _FakeClient(apps=api)) {
        with unittest.mock.patch.object(
            target_mod.KubernetesTarget, "_load_cluster_config", return_value=None
        ) {
            t = target_mod.KubernetesTarget(
                config=KubernetesConfig(app_name="shop", namespace="shop"),
                microservices_config={"routes": {}}
            );
            try {
                t.referenced_bundle_keys("shop");
            } except Exception {
                raised = True;
            }
            assert t.list_revisions("shop") == [] , (
                "list_revisions stays lenient; only the keep-set is strict"
            );
        }
    }

    assert raised , (
        "an empty keep-set from an unreadable cluster tells a pruner to delete "
        "every bundle the app references"
    );
}

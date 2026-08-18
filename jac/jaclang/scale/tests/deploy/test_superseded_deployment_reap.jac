import from types { SimpleNamespace }
import from jaclang.scale.config.app_config { AppConfig }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.deploy.target.kubernetes.target {
    KubernetesTarget,
    replica_sets_at_revision,
    restorable_pod_template,
    app_deployment_names,
    app_bundle_digest,
    releases_from_revisions,
    fleet_targets_for_release,
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
def _provisioned_redis(app: str) -> any {
    name = f"{app}-redis";
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
        items=[_current_deployment("standup"), _provisioned_redis("standup")]
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


test "only the ReplicaSets at the requested revision are selected" {
    # Newest last on purpose: both ReplicaSets key off the same Deployment, so a
    # selector that ignored the revision would leave revision 3 as the winner.
    sets = [
        _replica_set("orders-deployment", "2"),
        _replica_set("orders-deployment", "3"),
        _replica_set("gateway-deployment", "2")
    ];

    picked = replica_sets_at_revision(sets, 2);

    assert sorted(picked.keys()) == ["gateway-deployment", "orders-deployment"];
    assert picked["orders-deployment"].metadata.name == "orders-deployment-2";
}


test "an ownerless ReplicaSet is never a revert target" {
    picked = replica_sets_at_revision(
        [_replica_set("orders-deployment", "2", owned=False)], 2
    );

    assert picked == {};
}


test "a revision with no retained ReplicaSet selects nothing" {
    assert replica_sets_at_revision([_replica_set("orders-deployment", "3")], 1) == {};
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
test "the app's deployment set is derived from its own routes" {
    names = app_deployment_names(
        {"orders_app": "/orders", "cart_app": "/cart"}, "shop"
    );

    assert names
        == ["cart-app-deployment", "orders-app-deployment", "gateway-deployment"] , f"the gateway rolls back last, so it is listed last: {names}";
}


test "a monolith with no routes still resolves its own deployment" {
    assert app_deployment_names({}, "littlex")
        == ["littlex-deployment", "gateway-deployment"];
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

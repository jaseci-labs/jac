# KEDAAutoscaler/HPAAutoscaler.apply(), scoped to the 3 review-caught bugs
# with no other test net, per the "no unit tests, ~750 lines total" review
# pass:
#   - engine-switch cleanup: switching a target from the HPA engine to KEDA
#     must delete the HPA engine's own HPA, or the two autoscalers fight
#     over the same Deployment
#   - TriggerAuthentication pruning: a redeploy that drops a trigger's auth
#     must not leave the old TriggerAuthentication behind, unreferenced
#   - duplicate trigger identities must raise before any cluster write, or
#     two triggers silently overwrite each other's TriggerAuthentication
#
# Real production objects (KEDAAutoscaler/HPAAutoscaler) wired against a
# small stateful fake Kubernetes API double -- the same class-behind-a-
# patch-point pattern already used by test_cluster_provider.jac /
# test_k8s_utils.jac, just made stateful because this scenario needs to ask
# "is the object I created earlier still there" across steps. It enforces
# the same existence semantics a real apiserver would (patch/read 404 if
# missing, create 409-conflicts if already present) so a regression in
# apply()'s get-then-patch-or-create branching is caught, not rubber-
# stamped. get_runtime_status/preflight/destroy are exercised only as far
# as apply() itself calls them (preflight always succeeds here) -- see
# PR review notes for the coverage this consolidation accepts skipping.
import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.scale.deploy.autoscale.keda_autoscaler { KEDAAutoscaler }
import from jaclang.scale.deploy.autoscale.hpa_autoscaler { HPAAutoscaler }
import from jaclang.scale.deploy.autoscale.autoscaler {
    AutoscalerSpec,
    Trigger,
    TriggerAuth
}
import from jaclang.scale.deploy.autoscale { hpa_autoscaler as hpa_module }


obj FakeV2Api {
    # Models AutoscalingV2Api's HPA lifecycle. 404 if missing, 409 if
    # already present -- so apply()'s read-then-patch-or-create branching
    # is actually exercised.
    has store: dict = {};

    def read_namespaced_horizontal_pod_autoscaler(name: str, namespace: str) -> dict {
        if name not in self.store {
            raise ApiException(status=404);
        }
        return self.store[name];
    }

    def create_namespaced_horizontal_pod_autoscaler(
        namespace: str, body: dict
    ) -> dict {
        name = body["metadata"]["name"];
        if name in self.store {
            raise ApiException(status=409);
        }
        self.store[name] = body;
        return body;
    }

    def delete_namespaced_horizontal_pod_autoscaler(name: str, namespace: str) {
        if name not in self.store {
            raise ApiException(status=404);
        }
        del self.store[name];
    }
}


obj FakeCustomObjectsApi {
    # Models CustomObjectsApi (ScaledObject/TriggerAuthentication) against
    # an in-memory store keyed by "<plural>/<name>", with the same
    # existence-strict semantics as FakeV2Api above.
    has store: dict = {};

    def _key(plural: str, name: str) -> str {
        return f"{plural}/{name}";
    }

    def _label_selector_matches(labels: dict, selector: (str | None)) -> bool {
        if not selector {
            return True;
        }
        for pair in selector.split(",") {
            (k, _, v) = pair.partition("=");
            if labels.get(k) != v {
                return False;
            }
        }
        return True;
    }

    def get_namespaced_custom_object(
        group: str, version: str, namespace: str, plural: str, name: str
    ) -> dict {
        key = self._key(plural, name);
        if key not in self.store {
            raise ApiException(status=404);
        }
        return self.store[key];
    }

    def create_namespaced_custom_object(
        group: str, version: str, namespace: str, plural: str, body: dict
    ) -> dict {
        key = self._key(plural, body["metadata"]["name"]);
        if key in self.store {
            raise ApiException(status=409);
        }
        self.store[key] = body;
        return body;
    }

    def patch_namespaced_custom_object(
        group: str, version: str, namespace: str, plural: str, name: str, body: dict
    ) -> dict {
        key = self._key(plural, name);
        if key not in self.store {
            raise ApiException(status=404);
        }
        self.store[key] = body;
        return body;
    }

    def delete_namespaced_custom_object(
        group: str, version: str, namespace: str, plural: str, name: str
    ) {
        key = self._key(plural, name);
        if key not in self.store {
            raise ApiException(status=404);
        }
        del self.store[key];
    }

    def list_namespaced_custom_object(
        group: str,
        version: str,
        namespace: str,
        plural: str,
        label_selector: (str | None) = None
    ) -> dict {
        items = [
            body
            for (key, body) in self.store.items()
            if key.startswith(f"{plural}/")
                and self._label_selector_matches(
                    body["metadata"].get("labels", {}), label_selector
                )
        ];
        return {"items": items};
    }

    def list_cluster_custom_object(group: str, version: str, plural: str) -> dict {
        return {"items": []};
    }
}


test "KEDAAutoscaler.apply(): engine-switch cleanup, TriggerAuthentication pruning, and duplicate-trigger rejection" {
    KEDAAutoscaler._preflight_cache.clear();
    v2 = FakeV2Api();
    custom = FakeCustomObjectsApi();

    def step_engine_switch_deletes_competing_hpa {
        with unittest.mock.patch.object(
            hpa_module, "AutoscalingV2Api", lambda { v2; }
        ) {
            with unittest.mock.patch.object(
                hpa_module.client, "CustomObjectsApi", lambda { custom; }
            ) {
                spec = AutoscalerSpec(
                    scale_target_name="svc-deployment",
                    app_name="svc",
                    namespace="default",
                    autoscaler_name="svc-hpa",
                    triggers=[Trigger(type="cpu", metadata={})]
                );
                assert HPAAutoscaler().apply(spec) is True;
                assert "svc-hpa" in v2.store;
            }
        }

        keda_spec = AutoscalerSpec(
            scale_target_name="svc-deployment",
            app_name="svc",
            namespace="default",
            triggers=[
                Trigger(type="cpu", metadata={}, name="cpu-load"),
                Trigger(
                    type="redis",
                    metadata={"address": "redis:6379"},
                    name="cache",
                    auth=TriggerAuth(
                        secret_refs={"password": {"name": "redis-secret", "key": "pw"}}
                    )
                )
            ]
        );
        keda = KEDAAutoscaler(_custom_api=custom, _v2_api=v2);
        assert keda.apply(keda_spec) is True;

        assert "svc-hpa" not in v2.store , "switching engines must delete the HPA-engine's own HPA";
        so_key = custom._key("scaledobjects", "svc-scaledobject");
        assert so_key in custom.store;
        assert len(custom.store[so_key]["spec"]["triggers"]) == 2;

        ta_entries = [
            key
            for key in custom.store
            if key.startswith("triggerauthentications/")
        ];
        assert len(ta_entries) == 1 , "only the auth-bearing trigger gets a TriggerAuthentication";
        auth_ref_name = custom.store[so_key]["spec"]["triggers"][1]["authenticationRef"][
            "name"
        ];
        assert custom.store[ta_entries[0]]["metadata"]["name"] == auth_ref_name , "TriggerAuthentication name must match the ScaledObject's authenticationRef";
    }

    def step_redeploy_prunes_orphaned_trigger_auth {
        assert len(
            [
                k
                for k in custom.store
                if k.startswith("triggerauthentications/")
            ]
        )
            == 1;

        spec = AutoscalerSpec(
            scale_target_name="svc-deployment",
            app_name="svc",
            namespace="default",
            triggers=[Trigger(type="cpu", metadata={}, name="cpu-load")]
        );
        keda = KEDAAutoscaler(_custom_api=custom, _v2_api=v2);
        assert keda.apply(spec) is True;

        ta_entries_after = [
            k
            for k in custom.store
            if k.startswith("triggerauthentications/")
        ];
        assert ta_entries_after == [] , "the redis trigger's auth is no longer referenced and must be pruned";

        so_key = custom._key("scaledobjects", "svc-scaledobject");
        assert so_key in custom.store , "the still-referenced ScaledObject must persist";
        assert len(custom.store[so_key]["spec"]["triggers"]) == 1;
    }

    def step_duplicate_trigger_identity_rejected_before_any_write {
        store_snapshot = dict(custom.store);
        v2_snapshot = dict(v2.store);

        spec = AutoscalerSpec(
            scale_target_name="svc-deployment",
            app_name="svc",
            namespace="default",
            triggers=[
                Trigger(
                    type="redis",
                    metadata={},
                    name="cache",
                    auth=TriggerAuth(
                        secret_refs={"password": {"name": "redis-secret", "key": "pw"}}
                    )
                ),
                Trigger(
                    type="rabbitmq",
                    metadata={},
                    name="cache",
                    auth=TriggerAuth(
                        secret_refs={"password": {"name": "rmq-secret", "key": "pw"}}
                    )
                )
            ]
        );
        keda = KEDAAutoscaler(_custom_api=custom, _v2_api=v2);
        raised = False;
        try {
            keda.apply(spec);
        } except ValueError as e {
            raised = True;
            assert "cache" in str(e);
        }
        assert raised;
        assert custom.store == store_snapshot , "a rejected spec must not touch the cluster at all";
        assert v2.store == v2_snapshot;
    }

    step_engine_switch_deletes_competing_hpa();
    step_redeploy_prunes_orphaned_trigger_auth();
    step_duplicate_trigger_identity_rejected_before_any_write();
}

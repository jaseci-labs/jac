import os;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes.microservice.manifest_builder {
    MicroserviceManifestBuilder,
    merge_manifest_overlay
}
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.config.config_loader { JacScaleConfig }


def _builder(services: dict) -> MicroserviceManifestBuilder {
    return MicroserviceManifestBuilder(
        k8s_config=KubernetesConfig(app_name="t", namespace="t-ns"),
        microservices_config={"services": services},
        dry_run=True
    );
}


test "overlay merges maps recursively and replaces scalars" {
    base = {"spec": {"replicas": 1, "strategy": {"type": "RollingUpdate"}}};
    overlay = {"spec": {"replicas": 3, "progressDeadlineSeconds": 1200}};
    merged = merge_manifest_overlay(base, overlay);
    assert merged["spec"]["replicas"] == 3;
    assert merged["spec"]["progressDeadlineSeconds"] == 1200;
    assert merged["spec"]["strategy"]["type"] == "RollingUpdate";
}

test "named lists merge by name, appending unmatched entries" {
    base = [{"name": "app", "image": "x", "env": [{"name": "A", "value": "1"}]}];
    overlay = [
        {"name": "app", "env": [{"name": "B", "value": "2"}]},
        {"name": "sidecar", "image": "y"}
    ];
    merged = merge_manifest_overlay(base, overlay);
    assert len(merged) == 2;
    assert merged[0]["image"] == "x";
    env_names = [e["name"] for e in merged[0]["env"]];
    assert env_names == ["A", "B"];
    assert merged[1]["name"] == "sidecar";
}

test "unnamed lists are replaced wholesale" {
    merged = merge_manifest_overlay({"args": ["a", "b"]}, {"args": ["c"]});
    assert merged["args"] == ["c"];
}

test "deployment manifest applies the service overlay on the first build" {
    b = _builder(
        {
            "billing_ops": {
                "deployment_overlay": {
                    "spec": {
                        "progressDeadlineSeconds": 1200,
                        "template": {
                            "spec": {
                                "nodeSelector": {
                                    "karpenter.sh/capacity-type": "on-demand"
                                },
                                "automountServiceAccountToken": True,
                                "containers": [
                                    {
                                        "name": "billing-ops",
                                        "readinessProbe": {
                                            "initialDelaySeconds": 20,
                                            "periodSeconds": 5
                                        },
                                        "env": [{"name": "EXTRA", "value": "1"}]
                                    }
                                ]
                            }
                        }
                    }
                }
            }
        }
    );
    pod_spec = {
        "containers": [
            {
                "name": "billing-ops",
                "image": "img",
                "env": [{"name": "JAC_SV_NAME", "value": "billing_ops"}],
                "readinessProbe": {
                    "httpGet": {"path": "/healthz", "port": 8000},
                    "initialDelaySeconds": 60,
                    "periodSeconds": 20
                }
            }
        ]
    };
    m = b._build_deployment_manifest("billing_ops", pod_spec);
    spec = m["spec"]["template"]["spec"];
    assert m["spec"]["progressDeadlineSeconds"] == 1200;
    assert spec["nodeSelector"]["karpenter.sh/capacity-type"] == "on-demand";
    assert spec["automountServiceAccountToken"] is True;
    c = spec["containers"][0];

    assert c["image"] == "img";
    assert c["readinessProbe"]["initialDelaySeconds"] == 20;
    assert c["readinessProbe"]["periodSeconds"] == 5;
    assert c["readinessProbe"]["httpGet"]["path"] == "/healthz";
    env_names = [e["name"] for e in c["env"]];
    assert "JAC_SV_NAME" in env_names and "EXTRA" in env_names;
}

test "overlay cannot detach identity or routing fields" {
    b = _builder(
        {
            "svc_a": {
                "deployment_overlay": {
                    "metadata": {
                        "name": "hijacked",
                        "namespace": "elsewhere",
                        "labels": {"app": "other", "managed": "hijacked"}
                    },
                    "spec": {
                        "selector": {"matchLabels": {"app": "other"}},
                        "template": {"metadata": {"labels": {"app": "other"}}}
                    }
                }
            }
        }
    );
    m = b._build_deployment_manifest("svc_a", {"containers": []});
    assert m["metadata"]["name"] == "svc-a-deployment";
    assert m["metadata"]["namespace"] == "t-ns";
    assert m["metadata"]["labels"]["app"] == "svc-a";
    assert m["metadata"]["labels"]["managed"] == "jac-scale";
    assert m["spec"]["selector"]["matchLabels"]["app"] == "svc-a";
    assert m["spec"]["template"]["metadata"]["labels"]["app"] == "svc-a";
    assert m["spec"]["template"]["metadata"]["labels"]["managed"] == "jac-scale";
}

test "no overlay leaves the manifest untouched" {
    b = _builder({"svc_a": {}});
    m = b._build_deployment_manifest("svc_a", {"containers": []});
    assert m["spec"]["strategy"]["rollingUpdate"]["maxSurge"] == 1;
    assert "progressDeadlineSeconds" not in dict(m["spec"]);
}

test "JAC_PROFILE overlay file reaches the scale plugin config" {
    import tempfile;
    tmp = tempfile.mkdtemp();
    with open(os.path.join(tmp, "jac.toml"), "w") as f {
        f.write(
            '[project]\nname = "t"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n' + '[scale.kubernetes]\nnamespace = "prod-ns"\nmin_replicas = 3\n'
        );
    }
    with open(os.path.join(tmp, "jac.preview.toml"), "w") as f {
        f.write('[scale.kubernetes]\nmin_replicas = 1\n');
    }
    old = os.environ.get("JAC_PROFILE");
    os.environ["JAC_PROFILE"] = "preview";
    try {
        cfg = JacScaleConfig(project_dir=Path(tmp)).get_kubernetes_config();
        assert cfg.get("min_replicas") == 1;
        assert cfg.get("namespace") == "prod-ns";
    } finally {
        if old is None {
            del os.environ["JAC_PROFILE"];
        } else {
            os.environ["JAC_PROFILE"] = old;
        }
    }
}

test "deprecated JAC_ENV still selects the profile for plugin configs" {
    import tempfile;
    tmp = tempfile.mkdtemp();
    with open(os.path.join(tmp, "jac.toml"), "w") as f {
        f.write(
            '[project]\nname = "t"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n' + '[scale.kubernetes]\nmin_replicas = 3\n'
        );
    }
    with open(os.path.join(tmp, "jac.preview.toml"), "w") as f {
        f.write('[scale.kubernetes]\nmin_replicas = 1\n');
    }
    old_profile = os.environ.pop("JAC_PROFILE", None);
    old_env = os.environ.get("JAC_ENV");
    os.environ["JAC_ENV"] = "preview";
    try {
        cfg = JacScaleConfig(project_dir=Path(tmp)).get_kubernetes_config();
        assert cfg.get("min_replicas") == 1;
    } finally {
        if old_env is None {
            del os.environ["JAC_ENV"];
        } else {
            os.environ["JAC_ENV"] = old_env;
        }
        if old_profile is not None {
            os.environ["JAC_PROFILE"] = old_profile;
        }
    }
}

test "without JAC_PROFILE the base config is unchanged" {
    import tempfile;
    tmp = tempfile.mkdtemp();
    with open(os.path.join(tmp, "jac.toml"), "w") as f {
        f.write(
            '[project]\nname = "t"\nversion = "0.0.1"\nentry-point = "main.jac"\n\n' + '[scale.kubernetes]\nmin_replicas = 3\n'
        );
    }
    with open(os.path.join(tmp, "jac.preview.toml"), "w") as f {
        f.write('[scale.kubernetes]\nmin_replicas = 1\n');
    }
    old = os.environ.pop("JAC_PROFILE", None);
    try {
        cfg = JacScaleConfig(project_dir=Path(tmp)).get_kubernetes_config();
        assert cfg.get("min_replicas") == 3;
    } finally {
        if old is not None {
            os.environ["JAC_PROFILE"] = old;
        }
    }
}

test "embedder-supplied config gets schema defaults (client entry included)" {
    b = _builder({"svc_a": {}});
    cfg = b._ms_cfg();
    assert cfg["client"]["entry"] == "main.jac";
    assert cfg["gateway_port"] == 8000;
    assert cfg["services"] == {"svc_a": {}};
}


test "embedder overrides survive normalization" {
    b = MicroserviceManifestBuilder(
        k8s_config=KubernetesConfig(app_name="t", namespace="t-ns"),
        microservices_config={
            "gateway_port": 9001,
            "client": {"entry": False},
            "services": {"svc_a": {}}
        },
        dry_run=True
    );
    cfg = b._ms_cfg();
    assert cfg["gateway_port"] == 9001;
    assert cfg["client"]["entry"] == "";
    assert cfg["drain_timeout_seconds"] == 10.0;
}

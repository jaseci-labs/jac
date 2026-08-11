import unittest.mock;
import from jaclang.scale._optdeps.optional_deps {
    require_optional,
    is_optional_available
}
import from jaclang.scale._optdeps.prometheus { HAS_PROMETHEUS, Counter }
import from jaclang.scale._optdeps.apscheduler { HAS_APSCHEDULER, BackgroundScheduler }
import from jaclang.scale._optdeps.kubernetes { HAS_KUBERNETES, client as k8s_client }
import from jaclang.scale._optdeps.gcs { HAS_GCS, StorageClient }

test "require_optional does not raise for installed stdlib package" {
    require_optional("json", "serve");
}

test "require_optional raises ImportError for missing package" {
    raised = False;
    try {
        require_optional("nonexistent_package_xyz", "storage.s3");
    } except ImportError as e {
        raised = True;
        assert "nonexistent_package_xyz" in str(e);
        # capability-oriented message sourced from the core registry; the old
        # jac-scale[...] extras taxonomy is gone.
        assert "storage.s3" in str(e);
        assert "jac install" in str(e);
        assert "jac-scale[" not in str(e);
    }
    assert raised , "Expected ImportError for missing package";
}

test "require_optional error names the capability, not a pip extra" {
    raised = False;
    try {
        require_optional("nonexistent_package_xyz", "monitoring");
    } except ImportError as e {
        raised = True;
        assert "monitoring" in str(e);
        assert "jac-scale[" not in str(e);
    }
    assert raised , "Expected ImportError naming the capability";
}

test "is_optional_available returns True for installed package" {
    assert is_optional_available("json") is True;
}

test "is_optional_available returns False for missing package" {
    assert is_optional_available("nonexistent_package_xyz") is False;
}

test "HAS flags are booleans" {
    assert isinstance(HAS_PROMETHEUS, bool);
    assert isinstance(HAS_APSCHEDULER, bool);
    assert isinstance(HAS_KUBERNETES, bool);
    assert isinstance(HAS_GCS, bool);
}

test "HAS flags match is_optional_available" {
    assert HAS_PROMETHEUS == is_optional_available("prometheus_client");
    assert HAS_APSCHEDULER == is_optional_available("apscheduler");
    assert HAS_KUBERNETES == is_optional_available("kubernetes");
    assert HAS_GCS == is_optional_available("google.cloud.storage");
}

test "retired database shims are gone (#8000)" {
    import importlib.util;
    for shim in ["pymongo", "redis", "firestore"] {
        spec = importlib.util.find_spec(f"jaclang.scale._optdeps.{shim}");
        assert spec is None , f"_optdeps.{shim} should have been deleted";
    }
}

test "prometheus exports are real when installed" {
    if HAS_PROMETHEUS {
        assert Counter is not None;
        assert callable(Counter);
    } else {
        assert Counter is None;
    }
}

test "apscheduler exports are real when installed" {
    if HAS_APSCHEDULER {
        assert BackgroundScheduler is not None;
        assert callable(BackgroundScheduler);
    } else {
        assert BackgroundScheduler is None;
    }
}

test "kubernetes exports are real when installed" {
    if HAS_KUBERNETES {
        assert k8s_client is not None;
    } else {
        assert k8s_client is None;
    }
}


test "gcs exports are real when installed" {
    if HAS_GCS {
        assert StorageClient is not None;
        assert callable(StorageClient);
    } else {
        assert StorageClient is None;
    }
}

test "utility factory returns noop metrics when prometheus missing" {
    import from jaclang.scale.observability.factory { UtilityFactory }
    import from jaclang.scale.observability.metrics { NoOpMetricsCollector }

    with unittest.mock.patch(
        "jaclang.scale.observability.factory.is_optional_available", return_value=False
    ) {
        config = {"enabled": True, "namespace": "test"};
        collector = UtilityFactory.create_metrics("prometheus", config);
        assert isinstance(collector, NoOpMetricsCollector) , "Should fall back to NoOp when prometheus-client is missing";
    }
}

test "utility factory returns prometheus when available" {
    if not HAS_PROMETHEUS {
        return;
    }
    import from jaclang.scale.observability.factory { UtilityFactory }
    import from jaclang.scale.observability.prometheus_metrics {
        PrometheusMetricsCollector
    }

    config = {"enabled": True, "namespace": "test_avail"};
    collector = UtilityFactory.create_metrics("prometheus", config);
    assert isinstance(collector, PrometheusMetricsCollector);
}

test "deployment factory requires kubernetes for k8s target" {
    import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }

    with unittest.mock.patch(
        "jaclang.scale.deploy.target.factory.require_optional",
        side_effect=ImportError(
            "'kubernetes' is required for this feature. "
            "Capability 'deploy.k8s' is required but not installed."
        )
    ) {
        raised = False;
        try {
            DeploymentTargetFactory.create("kubernetes", {"app_name": "test"});
        } except ImportError as e {
            raised = True;
            assert "deploy.k8s" in str(e);
            assert "jac-scale[" not in str(e);
        }
        assert raised , "Expected ImportError when kubernetes is missing";
    }
}

test "require_optional with empty package name raises" {
    raised = False;
    try {
        require_optional("", "storage.s3");
    } except ImportError {
        raised = True;
    }
    assert raised , "Expected ImportError for empty package name";
}

test "is_optional_available with empty string returns False" {
    assert is_optional_available("") is False;
}

test "compat modules are always importable" {
    import jaclang.scale._optdeps.prometheus;
    import jaclang.scale._optdeps.apscheduler;
    import jaclang.scale._optdeps.kubernetes;
    assert hasattr(jaclang.scale._optdeps.prometheus, "HAS_PROMETHEUS");
    assert hasattr(jaclang.scale._optdeps.apscheduler, "HAS_APSCHEDULER");
    assert hasattr(jaclang.scale._optdeps.kubernetes, "HAS_KUBERNETES");
}

test "multiple require_optional calls do not conflict" {
    require_optional("json", "serve");
    require_optional("json", "serve");
    require_optional("os", "serve");
}

test "scheduler setup succeeds without apscheduler installed" {
    import from jaclang.scale.scheduler.scheduler { JacScaleScheduler }

    with unittest.mock.patch(
        "jaclang.scale.scheduler.scheduler.HAS_APSCHEDULER", False
    ) {
        with unittest.mock.patch(
            "jaclang.scale.scheduler.scheduler.BackgroundScheduler", None
        ) {
            with unittest.mock.patch(
                "jaclang.scale.scheduler.scheduler.ThreadPoolExecutor", None
            ) {
                sched = JacScaleScheduler();
                sched.setup(system_user_id="system-user-id");
                assert sched._apscheduler is None , "APScheduler should be None when package is not installed";
                sched.start();
                sched.stop();
            }
        }
    }
}

test "scheduler create_job raises clear error without apscheduler" {
    import from jaclang.scale.scheduler.scheduler { JacScaleScheduler }

    with unittest.mock.patch(
        "jaclang.scale.scheduler.scheduler.HAS_APSCHEDULER", False
    ) {
        with unittest.mock.patch(
            "jaclang.scale.scheduler.scheduler.BackgroundScheduler", None
        ) {
            with unittest.mock.patch(
                "jaclang.scale.scheduler.scheduler.ThreadPoolExecutor", None
            ) {
                sched = JacScaleScheduler();
                sched.setup(system_user_id="system-user-id");
                raised = False;
                try {
                    import from jaclang.scale.scheduler.scheduler { TriggerSpec }
                    spec = TriggerSpec.validate(trigger="interval", interval=60.0);
                    sched.create_job(
                        name="test_walker", spec=spec, created_by="system-user-id"
                    );
                } except RuntimeError as e {
                    raised = True;
                    assert "scheduler" in str(e) , "Error message should name the scheduler capability";
                    assert "jac-scale[" not in str(e);
                }
                assert raised , "Expected RuntimeError when creating job without APScheduler";
            }
        }
    }
}

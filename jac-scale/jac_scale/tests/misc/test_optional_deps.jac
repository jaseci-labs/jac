import unittest.mock;
import from jac_scale._optdeps.optional_deps { require_optional, is_optional_available }
import from jac_scale._optdeps.pymongo { HAS_PYMONGO, MongoClient }
import from jac_scale._optdeps.redis { HAS_REDIS, Redis }
import from jac_scale._optdeps.prometheus { HAS_PROMETHEUS, Counter }
import from jac_scale._optdeps.apscheduler { HAS_APSCHEDULER, BackgroundScheduler }
import from jac_scale._optdeps.kubernetes { HAS_KUBERNETES, client as k8s_client }
import from jac_scale._optdeps.gcs { HAS_GCS, StorageClient }

test "require_optional does not raise for installed stdlib package" {
    require_optional("json", "core");
}

test "require_optional does not raise for installed package" {
    require_optional("fastapi", "core");
}

test "require_optional raises ImportError for missing package" {
    raised = False;
    try {
        require_optional("nonexistent_package_xyz", "data");
    } except ImportError as e {
        raised = True;
        assert "nonexistent_package_xyz" in str(e);
        assert "pip install jac-scale[data]" in str(e);
    }
    assert raised , "Expected ImportError for missing package";
}

test "require_optional error includes correct install group" {
    raised = False;
    try {
        require_optional("nonexistent_package_xyz", "monitoring");
    } except ImportError as e {
        raised = True;
        assert "pip install jac-scale[monitoring]" in str(e);
    }
    assert raised , "Expected ImportError with correct group name";
}

test "is_optional_available returns True for installed package" {
    assert is_optional_available("json") is True;
    assert is_optional_available("fastapi") is True;
}

test "is_optional_available returns False for missing package" {
    assert is_optional_available("nonexistent_package_xyz") is False;
}

test "HAS flags are booleans" {
    assert isinstance(HAS_PYMONGO, bool);
    assert isinstance(HAS_REDIS, bool);
    assert isinstance(HAS_PROMETHEUS, bool);
    assert isinstance(HAS_APSCHEDULER, bool);
    assert isinstance(HAS_KUBERNETES, bool);
    assert isinstance(HAS_GCS, bool);
}

test "HAS flags match is_optional_available" {
    assert HAS_PYMONGO == is_optional_available("pymongo");
    assert HAS_REDIS == is_optional_available("redis");
    assert HAS_PROMETHEUS == is_optional_available("prometheus_client");
    assert HAS_APSCHEDULER == is_optional_available("apscheduler");
    assert HAS_KUBERNETES == is_optional_available("kubernetes");
    assert HAS_GCS == is_optional_available("google.cloud.storage");
}

test "pymongo exports are real when installed" {
    if HAS_PYMONGO {
        assert MongoClient is not None;
        assert callable(MongoClient);
    } else {
        assert MongoClient is None;
    }
}

test "redis exports are real when installed" {
    if HAS_REDIS {
        assert Redis is not None;
    } else {
        assert Redis is None;
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
    import from jac_scale.observability.factory { UtilityFactory }
    import from jac_scale.observability.metrics { NoOpMetricsCollector }

    with unittest.mock.patch(
        "jac_scale.observability.factory.is_optional_available", return_value=False
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
    import from jac_scale.observability.factory { UtilityFactory }
    import from jac_scale.observability.prometheus_metrics {
        PrometheusMetricsCollector
    }

    config = {"enabled": True, "namespace": "test_avail"};
    collector = UtilityFactory.create_metrics("prometheus", config);
    assert isinstance(collector, PrometheusMetricsCollector);
}

test "database factory requires pymongo for mongodb" {
    import from jac_scale.deploy.database.factory {
        DatabaseProviderFactory,
        DatabaseType
    }

    with unittest.mock.patch(
        "jac_scale.deploy.database.factory.require_optional",
        side_effect=ImportError(
            "'pymongo' is required. Install: pip install jac-scale[data]"
        )
    ) {
        raised = False;
        try {
            DatabaseProviderFactory.create_client(
                DatabaseType.MONGODB, uri="mongodb://localhost"
            );
        } except ImportError as e {
            raised = True;
            assert "jac-scale[data]" in str(e);
        }
        assert raised , "Expected ImportError when pymongo is missing";
    }
}

test "database factory requires redis for redis" {
    import from jac_scale.deploy.database.factory {
        DatabaseProviderFactory,
        DatabaseType
    }

    with unittest.mock.patch(
        "jac_scale.deploy.database.factory.require_optional",
        side_effect=ImportError(
            "'redis' is required. Install: pip install jac-scale[data]"
        )
    ) {
        raised = False;
        try {
            DatabaseProviderFactory.create_client(
                DatabaseType.REDIS, uri="redis://localhost"
            );
        } except ImportError as e {
            raised = True;
            assert "jac-scale[data]" in str(e);
        }
        assert raised , "Expected ImportError when redis is missing";
    }
}

test "database factory requires firestore for firestore" {
    import from jac_scale.deploy.database.factory {
        DatabaseProviderFactory,
        DatabaseType
    }

    with unittest.mock.patch(
        "jac_scale.deploy.database.factory.require_optional",
        side_effect=ImportError(
            "'google.cloud.firestore' is required. Install: pip install jac-scale[firebase]"
        )
    ) {
        raised = False;
        try {
            DatabaseProviderFactory.create_client(
                DatabaseType.FIRESTORE, uri="firebase-project"
            );
        } except ImportError as e {
            raised = True;
            assert "jac-scale[firebase]" in str(e);
        }
        assert raised , "Expected ImportError when google-cloud-firestore is missing";
    }
}

test "deployment factory requires kubernetes for k8s target" {
    import from jac_scale.deploy.target.factory { DeploymentTargetFactory }

    with unittest.mock.patch(
        "jac_scale.deploy.target.factory.require_optional",
        side_effect=ImportError(
            "'kubernetes' is required. Install: pip install jac-scale[deploy]"
        )
    ) {
        raised = False;
        try {
            DeploymentTargetFactory.create("kubernetes", {"app_name": "test"});
        } except ImportError as e {
            raised = True;
            assert "jac-scale[deploy]" in str(e);
        }
        assert raised , "Expected ImportError when kubernetes is missing";
    }
}

test "require_optional with empty package name raises" {
    raised = False;
    try {
        require_optional("", "data");
    } except ImportError {
        raised = True;
    }
    assert raised , "Expected ImportError for empty package name";
}

test "is_optional_available with empty string returns False" {
    assert is_optional_available("") is False;
}

test "compat modules are always importable" {
    import jac_scale._optdeps.pymongo;
    import jac_scale._optdeps.redis;
    import jac_scale._optdeps.prometheus;
    import jac_scale._optdeps.apscheduler;
    import jac_scale._optdeps.kubernetes;
    assert hasattr(jac_scale._optdeps.pymongo, "HAS_PYMONGO");
    assert hasattr(jac_scale._optdeps.redis, "HAS_REDIS");
    assert hasattr(jac_scale._optdeps.prometheus, "HAS_PROMETHEUS");
    assert hasattr(jac_scale._optdeps.apscheduler, "HAS_APSCHEDULER");
    assert hasattr(jac_scale._optdeps.kubernetes, "HAS_KUBERNETES");
}

test "multiple require_optional calls do not conflict" {
    require_optional("json", "core");
    require_optional("json", "core");
    require_optional("os", "core");
}

test "scheduler setup succeeds without apscheduler installed" {
    import from jac_scale.scheduler.scheduler { JacScaleScheduler }

    with unittest.mock.patch("jac_scale.scheduler.scheduler.HAS_APSCHEDULER", False) {
        with unittest.mock.patch(
            "jac_scale.scheduler.scheduler.BackgroundScheduler", None
        ) {
            with unittest.mock.patch(
                "jac_scale.scheduler.scheduler.ThreadPoolExecutor", None
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
    import from jac_scale.scheduler.scheduler { JacScaleScheduler }

    with unittest.mock.patch("jac_scale.scheduler.scheduler.HAS_APSCHEDULER", False) {
        with unittest.mock.patch(
            "jac_scale.scheduler.scheduler.BackgroundScheduler", None
        ) {
            with unittest.mock.patch(
                "jac_scale.scheduler.scheduler.ThreadPoolExecutor", None
            ) {
                sched = JacScaleScheduler();
                sched.setup(system_user_id="system-user-id");
                raised = False;
                try {
                    import from jac_scale.scheduler.scheduler { TriggerSpec }
                    spec = TriggerSpec.validate(trigger="interval", interval=60.0);
                    sched.create_job(
                        name="test_walker", spec=spec, created_by="system-user-id"
                    );
                } except RuntimeError as e {
                    raised = True;
                    assert "jac-scale[scheduler]" in str(e) , "Error message should include install instructions";
                }
                assert raised , "Expected RuntimeError when creating job without APScheduler";
            }
        }
    }
}

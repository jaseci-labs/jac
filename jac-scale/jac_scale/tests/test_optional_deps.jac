"""Tests for optional dependency guards and install groups.

These tests verify that:
- Per-package compat modules re-export symbols correctly
- require_optional() raises clear errors for missing packages
- is_optional_available() reports correctly for installed packages
- Factories gracefully handle missing optional deps
- HAS_* flags reflect actual package availability
"""

import unittest.mock;
import from jac_scale._optdeps.optional_deps { require_optional, is_optional_available }
import from jac_scale._optdeps.pymongo { HAS_PYMONGO, MongoClient }
import from jac_scale._optdeps.redis { HAS_REDIS, Redis }
import from jac_scale._optdeps.prometheus { HAS_PROMETHEUS, Counter }
import from jac_scale._optdeps.apscheduler { HAS_APSCHEDULER, BackgroundScheduler }
import from jac_scale._optdeps.kubernetes { HAS_KUBERNETES, client as k8s_client }
import from jac_scale._optdeps.docker { HAS_DOCKER, docker_module }

# =============================================================================
# require_optional — happy path (installed packages)
# =============================================================================
test "require_optional does not raise for installed stdlib package" {
    # json is always available
    require_optional("json", "core");
}

test "require_optional does not raise for installed package" {
    # fastapi is a core dependency, always installed
    require_optional("fastapi", "core");
}

# =============================================================================
# require_optional — error messages
# =============================================================================
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

# =============================================================================
# is_optional_available
# =============================================================================
test "is_optional_available returns True for installed package" {
    assert is_optional_available("json") is True;
    assert is_optional_available("fastapi") is True;
}

test "is_optional_available returns False for missing package" {
    assert is_optional_available("nonexistent_package_xyz") is False;
}

# =============================================================================
# HAS_* flags reflect actual availability
# =============================================================================
test "HAS flags are booleans" {
    assert isinstance(HAS_PYMONGO, bool);
    assert isinstance(HAS_REDIS, bool);
    assert isinstance(HAS_PROMETHEUS, bool);
    assert isinstance(HAS_APSCHEDULER, bool);
    assert isinstance(HAS_KUBERNETES, bool);
    assert isinstance(HAS_DOCKER, bool);
}

test "HAS flags match is_optional_available" {
    assert HAS_PYMONGO == is_optional_available("pymongo");
    assert HAS_REDIS == is_optional_available("redis");
    assert HAS_PROMETHEUS == is_optional_available("prometheus_client");
    assert HAS_APSCHEDULER == is_optional_available("apscheduler");
    assert HAS_KUBERNETES == is_optional_available("kubernetes");
    assert HAS_DOCKER == is_optional_available("docker");
}

# =============================================================================
# Compat module exports real types when packages are installed
# =============================================================================
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

test "docker exports are real when installed" {
    if HAS_DOCKER {
        assert docker_module is not None;
    } else {
        assert docker_module is None;
    }
}

# =============================================================================
# Factory fallback behavior
# =============================================================================
test "utility factory returns noop metrics when prometheus missing" {
    import from jac_scale.factories.utility_factory { UtilityFactory }
    import from jac_scale.abstractions.metrics { NoOpMetricsCollector }

    with unittest.mock.patch(
        "jac_scale.factories.utility_factory.is_optional_available", return_value=False
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
    import from jac_scale.factories.utility_factory { UtilityFactory }
    import from jac_scale.utilities.metrics.prometheus_metrics {
        PrometheusMetricsCollector
    }

    config = {"enabled": True, "namespace": "test_avail"};
    collector = UtilityFactory.create_metrics("prometheus", config);
    assert isinstance(collector, PrometheusMetricsCollector);
}

test "database factory requires pymongo for mongodb" {
    import from jac_scale.factories.database_factory {
        DatabaseProviderFactory,
        DatabaseType
    }

    with unittest.mock.patch(
        "jac_scale.factories.database_factory.require_optional",
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
    import from jac_scale.factories.database_factory {
        DatabaseProviderFactory,
        DatabaseType
    }

    with unittest.mock.patch(
        "jac_scale.factories.database_factory.require_optional",
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

test "deployment factory requires kubernetes for k8s target" {
    import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }

    with unittest.mock.patch(
        "jac_scale.factories.deployment_factory.require_optional",
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

# =============================================================================
# Edge cases
# =============================================================================
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
    # Per-package compat modules must never fail to import regardless of what's installed
    import jac_scale._optdeps.pymongo;
    import jac_scale._optdeps.redis;
    import jac_scale._optdeps.prometheus;
    import jac_scale._optdeps.apscheduler;
    import jac_scale._optdeps.kubernetes;
    import jac_scale._optdeps.docker;
    assert hasattr(jac_scale._optdeps.pymongo, "HAS_PYMONGO");
    assert hasattr(jac_scale._optdeps.redis, "HAS_REDIS");
    assert hasattr(jac_scale._optdeps.prometheus, "HAS_PROMETHEUS");
    assert hasattr(jac_scale._optdeps.apscheduler, "HAS_APSCHEDULER");
    assert hasattr(jac_scale._optdeps.kubernetes, "HAS_KUBERNETES");
    assert hasattr(jac_scale._optdeps.docker, "HAS_DOCKER");
}

test "multiple require_optional calls do not conflict" {
    # Calling require_optional multiple times for the same installed package is fine
    require_optional("json", "core");
    require_optional("json", "core");
    require_optional("os", "core");
}

# =============================================================================
# Scheduler graceful degradation without APScheduler
# =============================================================================
test "scheduler setup succeeds without apscheduler installed" {
    import from jac_scale.scheduler { JacScaleScheduler }

    # Simulate APScheduler not being installed by patching the symbols
    # in the scheduler module (where setup() reads them at runtime).
    with unittest.mock.patch("jac_scale.scheduler.HAS_APSCHEDULER", False) {
        with unittest.mock.patch("jac_scale.scheduler.BackgroundScheduler", None) {
            with unittest.mock.patch("jac_scale.scheduler.ThreadPoolExecutor", None) {
                sched = JacScaleScheduler();
                # setup() should not crash — APScheduler init is skipped gracefully.
                sched.setup(system_token="test-token");
                assert sched._apscheduler is None , "APScheduler should be None when package is not installed";
                # start/stop should be no-ops, not errors.
                sched.start();
                sched.stop();
            }
        }
    }
}

test "scheduler create_job raises clear error without apscheduler" {
    import from jac_scale.scheduler { JacScaleScheduler }

    with unittest.mock.patch("jac_scale.scheduler.HAS_APSCHEDULER", False) {
        with unittest.mock.patch("jac_scale.scheduler.BackgroundScheduler", None) {
            with unittest.mock.patch("jac_scale.scheduler.ThreadPoolExecutor", None) {
                sched = JacScaleScheduler();
                sched.setup(system_token="test-token");
                raised = False;
                try {
                    sched.create_job(
                        name="test_walker", trigger="interval", interval=60.0
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

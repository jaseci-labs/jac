import from pathlib { Path }
import from tempfile { mkdtemp }
import from types { SimpleNamespace }
import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.runtimelib.test { parametrize }
import from jaclang.scale.deploy.target.kubernetes.utils { kubernetes_utils as utils }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    check_pods_restarted,
    ensure_pvc_exists,
    load_env_variables,
    parse_cpu_quantity,
    parse_memory_quantity,
    parse_storage_quantity,
    resize_pvc_if_needed,
    validate_resource_limits
}

def _test_parse_cpu_valid(pair: tuple) {
    raw = pair[0];
    expected = pair[1];
    result = parse_cpu_quantity(raw);
    assert abs(result - expected) < 1e-6 , f"parse_cpu_quantity({raw!r}) = {result}, expected {expected}";
}

with entry {
    parametrize(
        "parse cpu quantity valid",
        [("500m", 0.5), ("2", 2.0), (" 250 ", 250.0)],
        _test_parse_cpu_valid
    );
}

def _test_parse_cpu_invalid(raw: str) {
    raised = False;
    try {
        parse_cpu_quantity(raw);
    } except ValueError {
        raised = True;
    }
    assert raised , f"Expected ValueError for parse_cpu_quantity({raw!r})";
}

with entry {
    parametrize(
        "parse cpu quantity invalid", ["", "m", " m "], _test_parse_cpu_invalid
    );
}

def _test_parse_memory_valid(pair: tuple) {
    raw = pair[0];
    expected = pair[1];
    result = parse_memory_quantity(raw);
    assert abs(result - expected) < 1e-6 , f"parse_memory_quantity({raw!r}) = {result}, expected {expected}";
}

with entry {
    parametrize(
        "parse memory quantity valid",
        [("256Mi", float(256 * 1024 ** 2)), ("1Gi", float(1024 ** 3)), ("2", 2.0)],
        _test_parse_memory_valid
    );
}

def _test_parse_memory_invalid(raw: str) {
    raised = False;
    try {
        parse_memory_quantity(raw);
    } except ValueError {
        raised = True;
    }
    assert raised , f"Expected ValueError for parse_memory_quantity({raw!r})";
}

with entry {
    parametrize(
        "parse memory quantity invalid", ["", "Mi", " Gi "], _test_parse_memory_invalid
    );
}

test "validate resource limits accepts valid pairs" {
    validate_resource_limits("250m", "500m", "256Mi", "512Mi");
}

test "validate resource limits rejects lower limits" {
    raised = False;
    try {
        validate_resource_limits("500m", "250m", None, None);
    } except ValueError {
        raised = True;
    }
    assert raised , "Expected ValueError for lower limits";
}

test "validate resource limits rejects invalid quantity" {
    raised = False;
    try {
        validate_resource_limits("abc", "1", None, None);
    } except ValueError {
        raised = True;
    }
    assert raised , "Expected ValueError for invalid quantity";
}

test "load env variables reads env file" {
    tmp = Path(mkdtemp());
    env_dir = tmp / "app";
    env_dir.mkdir();
    env_file = env_dir / ".env";
    env_file.write_text("VAR1=1\nVAR2=two\n");

    env_vars = load_env_variables(str(env_dir));

    assert {"name": "VAR1", "value": "1"} in env_vars;
    assert {"name": "VAR2", "value": "two"} in env_vars;
}

test "ensure pvc exists skips when present" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespaced_persistent_volume_claim.return_value = object();

    ensure_pvc_exists(core_v1, "test-ns", "test-pvc", "5Gi");

    core_v1.create_namespaced_persistent_volume_claim.assert_not_called();
}

test "ensure pvc exists creates when missing" {
    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespaced_persistent_volume_claim.side_effect = ApiException(
        status=404
    );

    ensure_pvc_exists(
        core_v1,
        namespace="test-ns",
        pvc_name="test-pvc",
        storage_size="10Gi",
        storage_class="fast"
    );

    call_args = core_v1.create_namespaced_persistent_volume_claim.call_args;
    assert call_args is not None;
    (args, kwargs) = call_args;
    assert kwargs == {};
    assert args[0] == "test-ns";
    body = args[1];
    assert body["metadata"]["name"] == "test-pvc";
    assert body["spec"]["accessModes"] == ["ReadWriteOnce"];
    assert body["spec"]["resources"]["requests"]["storage"] == "10Gi";
    assert body["spec"]["storageClassName"] == "fast";
}

test "cluster type detects aws by provider" {
    class Node {
        def init(self, provider_id: str) {
            self.provider_id = provider_id;
            self.spec = SimpleNamespace(provider_id=provider_id);
            self.metadata = SimpleNamespace(labels={});
        }
    }

    class Response {
        def init(self) {
            self.items = [Node("aws://12345")];
        }
    }

    class FakeApi {
        def list_node(self) -> Response {
            return Response();
        }
    }

    with unittest.mock.patch.object(utils.client, "CoreV1Api", lambda : FakeApi()) {
        assert utils.cluster_type() == "aws";
    }
}

test "check pods restarted selector and return values" {
    app_name = "myapp";
    namespace = "test-ns";
    expected_labels = [
        app_name,
        f"{app_name}-redis",
        f"{app_name}-mongodb",
        f"{app_name}-grafana",
        f"{app_name}-prometheus",
        f"{app_name}-mongo-express",
        f"{app_name}-redis-insight"
    ];

    clean_container = unittest.mock.MagicMock();
    clean_container.state = unittest.mock.MagicMock();
    clean_container.state.waiting = None;
    clean_container.restart_count = 0;

    pod_clean = unittest.mock.MagicMock();
    pod_clean.status.container_statuses = [clean_container];
    pod_clean.status.init_container_statuses = None;

    resp_clean = unittest.mock.MagicMock();
    resp_clean.items = [pod_clean];

    fake_v1 = unittest.mock.MagicMock();
    fake_v1.list_namespaced_pod.return_value = resp_clean;

    with unittest.mock.patch.object(utils.config, "load_kube_config") {
        with unittest.mock.patch.object(utils.client, "CoreV1Api", lambda : fake_v1 ) {
            result_false = check_pods_restarted(namespace, app_name);
        }
    }

    assert result_false is False;
    assert fake_v1.list_namespaced_pod.call_count == 1 , "expected single API call";
    selector = fake_v1.list_namespaced_pod.call_args[1]["label_selector"];
    for label in expected_labels {
        assert label in selector , f"Label '{label}' missing from selector '{selector}'";
    }

    crash_container = unittest.mock.MagicMock();
    crash_state = unittest.mock.MagicMock();
    crash_state.reason = "CrashLoopBackOff";
    crash_container.state = unittest.mock.MagicMock();
    crash_container.state.waiting = crash_state;
    crash_container.state.running = None;
    crash_container.restart_count = 1;

    pod_crash = unittest.mock.MagicMock();
    pod_crash.status.container_statuses = [crash_container];
    pod_crash.status.init_container_statuses = None;

    resp_restarted = unittest.mock.MagicMock();
    resp_restarted.items = [pod_crash];

    fake_v1.list_namespaced_pod.return_value = resp_restarted;

    with unittest.mock.patch.object(utils.config, "load_kube_config") {
        with unittest.mock.patch.object(utils.client, "CoreV1Api", lambda : fake_v1 ) {
            result_true = check_pods_restarted(namespace, app_name);
        }
    }

    assert result_true is True;

    stabilised_container = unittest.mock.MagicMock();
    stabilised_container.state = unittest.mock.MagicMock();
    stabilised_container.state.waiting = None;
    stabilised_container.state.running = unittest.mock.MagicMock();
    stabilised_container.restart_count = 1;

    pod_stabilised = unittest.mock.MagicMock();
    pod_stabilised.status.container_statuses = [stabilised_container];
    pod_stabilised.status.init_container_statuses = None;

    resp_stabilised = unittest.mock.MagicMock();
    resp_stabilised.items = [pod_stabilised];

    fake_v1.list_namespaced_pod.return_value = resp_stabilised;

    with unittest.mock.patch.object(utils.config, "load_kube_config") {
        with unittest.mock.patch.object(utils.client, "CoreV1Api", lambda : fake_v1 ) {
            result_stabilised = check_pods_restarted(namespace, app_name);
        }
    }

    assert result_stabilised is False , "pod that restarted once but is now running should not be flagged as crashed";
}

test "resize pvc if needed: increase patches, no-op skips, decrease raises" {
    def make_pvc(size: str) -> object {
        pvc = unittest.mock.MagicMock();
        pvc.spec.resources.requests = {"storage": size};
        return pvc;
    }

    core_v1 = unittest.mock.MagicMock();
    core_v1.read_namespaced_persistent_volume_claim.return_value = make_pvc("1Gi");
    resize_pvc_if_needed(core_v1, "ns", "mongo-pvc", "10Gi");
    core_v1.patch_namespaced_persistent_volume_claim.assert_called_once_with(
        "mongo-pvc", "ns", {"spec": {"resources": {"requests": {"storage": "10Gi"}}}}
    );

    core_v1_noop = unittest.mock.MagicMock();
    core_v1_noop.read_namespaced_persistent_volume_claim.return_value = make_pvc(
        "10Gi"
    );
    resize_pvc_if_needed(core_v1_noop, "ns", "mongo-pvc", "10Gi");
    core_v1_noop.patch_namespaced_persistent_volume_claim.assert_not_called();

    core_v1_shrink = unittest.mock.MagicMock();
    core_v1_shrink.read_namespaced_persistent_volume_claim.return_value = make_pvc(
        "10Gi"
    );
    raised = False;
    try {
        resize_pvc_if_needed(core_v1_shrink, "ns", "mongo-pvc", "1Gi");
    } except ValueError {
        raised = True;
    }
    assert raised , "Expected ValueError when trying to shrink PVC";

    core_v1_new = unittest.mock.MagicMock();
    core_v1_new.read_namespaced_persistent_volume_claim.side_effect = ApiException(
        status=404
    );
    resize_pvc_if_needed(core_v1_new, "ns", "mongo-pvc", "10Gi");
    core_v1_new.patch_namespaced_persistent_volume_claim.assert_not_called();
}

def _test_parse_storage_valid(pair: tuple) {
    raw = pair[0];
    expected = pair[1];
    result = parse_storage_quantity(raw);
    assert result == expected , f"parse_storage_quantity({raw!r}) = {result}, expected {expected}";
}

with entry {
    parametrize(
        "parse storage quantity valid",
        [
            ("1Ki", 1024),
            ("1Mi", 1024 ** 2),
            ("1Gi", 1024 ** 3),
            ("2Ti", 2 * 1024 ** 4),
            ("500", 500),
            ("1k", 1000),
            ("1M", 1000 ** 2),
            ("1G", 1000 ** 3),
            (" 4Gi ", 4 * 1024 ** 3)
        ],
        _test_parse_storage_valid
    );
}

def _test_parse_storage_invalid(raw: str) {
    raised = False;
    try {
        parse_storage_quantity(raw);
    } except ValueError {
        raised = True;
    }
    assert raised , f"Expected ValueError for parse_storage_quantity({raw!r})";
}

with entry {
    parametrize(
        "parse storage quantity invalid",
        ["", "abc", "Gi", "10X", "10gi", "10GI"],
        _test_parse_storage_invalid
    );
}

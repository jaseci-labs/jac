"""Tests for Kubernetes utility functions."""

import tarfile;
import from pathlib { Path }
import from tempfile { mkdtemp }
import from types { SimpleNamespace }
import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.runtimelib.test { parametrize }
import from jac_scale.targets.kubernetes.utils { kubernetes_utils as utils }
import from jac_scale.targets.kubernetes.utils.kubernetes_utils {
    create_tarball,
    ensure_pvc_exists,
    load_env_variables,
    parse_cpu_quantity,
    parse_memory_quantity,
    validate_resource_limits
}

# --- parse_cpu_quantity valid ---
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

# --- parse_cpu_quantity invalid ---
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

# --- parse_memory_quantity valid ---
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

# --- parse_memory_quantity invalid ---
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

# --- validate_resource_limits ---
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

# --- load_env_variables ---
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

# --- ensure_pvc_exists ---
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

# --- cluster_type detection ---
test "cluster type detects aws by provider" {
    class Node {
        def init(self, provider_id: str) {
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

# --- create_tarball ---
test "create tarball captures files" {
    tmp = Path(mkdtemp());
    source_dir = tmp / "src";
    source_dir.mkdir();
    file_path = source_dir / "hello.txt";
    file_path.write_text("hello");
    tar_path = tmp / "archive.tar.gz";

    create_tarball(str(source_dir), str(tar_path));

    assert tar_path.exists();
    with tarfile.open(tar_path, "r:gz") as tar {
        member_names = tar.getnames();
    }
    assert "./hello.txt" in member_names;
}

test "create tarball excludes jac folder" {
    tmp = Path(mkdtemp());
    source_dir = tmp / "src";
    source_dir.mkdir();
    (source_dir / "app.py").write_text("print('hi')");
    jac_dir = source_dir / ".jac";
    jac_dir.mkdir();
    (jac_dir / "cache.json").write_text("{}");
    tar_path = tmp / "archive.tar.gz";

    create_tarball(str(source_dir), str(tar_path));

    with tarfile.open(tar_path, "r:gz") as tar {
        member_names = tar.getnames();
    }
    assert "./app.py" in member_names;
    assert not any(".jac" in name for name in member_names);
}

test "create tarball missing source" {
    tmp = Path(mkdtemp());
    tar_path = tmp / "archive.tar.gz";

    raised = False;
    try {
        create_tarball(str(tmp / "missing"), str(tar_path));
    } except FileNotFoundError {
        raised = True;
    }
    assert raised , "Expected FileNotFoundError for missing source directory";
}

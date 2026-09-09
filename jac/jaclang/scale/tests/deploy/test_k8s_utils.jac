import from types { SimpleNamespace }
import unittest.mock;
import from kubernetes.client.exceptions { ApiException }
import from jaclang.testing.test { parametrize }
import from jaclang.scale.deploy.target.kubernetes.utils { kubernetes_utils as utils }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    parse_storage_quantity,
    resize_pvc_if_needed
}

test "cluster type detects aws by provider" {
    class Node {
        def init(self: Node, provider_id: str) {
            self.provider_id = provider_id;
            self.spec = SimpleNamespace(provider_id=provider_id);
            self.metadata = SimpleNamespace(labels={});
        }
    }

    class Response {
        def init(self: Response) {
            self.items = [Node("aws://12345")];
        }
    }

    class FakeApi {
        def list_node(self: FakeApi) -> Response {
            return Response();
        }
    }

    with unittest.mock.patch.object(utils.client, "CoreV1Api", lambda { FakeApi(); }) {
        assert utils.cluster_type() == "aws";
    }
}

test "a node probe that fails says so instead of silently answering local" {
    # An RBAC denial on list_node (nodes are cluster-scoped, and the ops Role
    # this surface grants does not include them) used to be indistinguishable
    # from minikube. LocalProvider then fabricates localhost node-port URLs and
    # skips the load balancer wait, so an EKS deploy reports wrong URLs with no
    # diagnostic anywhere.
    class FailingApi {
        def list_node(self: FailingApi) {
            raise ApiException(status=403, reason="Forbidden");
        }
    }

    class Recorder {
        def init(self: Recorder) {
            self.lines = [];
        }

        def print(self: Recorder, *args: any, **kwargs: any) {
            self.lines.append(" ".join(str(a) for a in args));
        }
    }

    recorder = Recorder();
    with unittest.mock.patch.object(
        utils.client, "CoreV1Api", lambda { FailingApi(); }
    ) {
        with unittest.mock.patch.object(utils, "console", recorder) {
            answer = utils.cluster_type();
        }
    }

    assert answer == "local" , (
        f"the fallback itself is unchanged, only its visibility: {answer}"
    );
    said = " ".join(recorder.lines);
    assert "403" in said and "Forbidden" in said , (
        f"the probe failure must name itself, not be swallowed: {recorder.lines}"
    );
    assert "localhost node ports" in said , (
        f"the warning must name the consequence, not just the failure: {recorder.lines}"
    );
}


test "a clean probe that finds no aws markers stays quiet" {
    # Only the unreadable case is worth a warning. A real local cluster must
    # not print one on every deploy.
    class Node {
        def init(self: Node) {
            self.spec = SimpleNamespace(provider_id="");
            self.metadata = SimpleNamespace(labels={});
        }
    }

    class Response {
        def init(self: Response) {
            self.items = [Node()];
        }
    }

    class LocalApi {
        def list_node(self: LocalApi) -> Response {
            return Response();
        }
    }

    class Recorder {
        def init(self: Recorder) {
            self.lines = [];
        }

        def print(self: Recorder, *args: any, **kwargs: any) {
            self.lines.append(" ".join(str(a) for a in args));
        }
    }

    recorder = Recorder();
    with unittest.mock.patch.object(
        utils.client, "CoreV1Api", lambda { LocalApi(); }
    ) {
        with unittest.mock.patch.object(utils, "console", recorder) {
            answer = utils.cluster_type();
        }
    }

    assert answer == "local";
    assert recorder.lines == [] , (
        f"a successful probe of a local cluster must not warn: {recorder.lines}"
    );
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

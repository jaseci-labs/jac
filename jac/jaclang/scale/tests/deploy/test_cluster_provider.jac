import from types { SimpleNamespace }
import unittest.mock;
import from jaclang.scale.deploy.target.kubernetes { cluster_provider as cp_module }
import from jaclang.scale.deploy.target.kubernetes.cluster_provider {
    AWSProvider,
    LocalProvider
}
import from jaclang.scale.deploy.target.kubernetes.utils { kubernetes_utils as utils }
import from jaclang.scale.deploy.target.kubernetes.utils.kubernetes_utils {
    get_cluster_provider
}

test "AWSProvider and LocalProvider honour their per-provider contracts" {
    aws = AWSProvider();
    local = LocalProvider();

    assert aws.service_type() == 'LoadBalancer';
    assert local.service_type() == 'NodePort';

    assert aws.needs_nlb_wait() is True;
    assert local.needs_nlb_wait() is False;

    assert aws.prometheus_scrape_port(8000) == 8000;
    assert aws.prometheus_scrape_port(3000) == 3000;
    assert local.prometheus_scrape_port(8000) == 8000;
    assert local.prometheus_scrape_port(3000) == 3000;

    assert aws.service_url("my-nlb.us-east-1.elb.amazonaws.com", 30080) == "http://my-nlb.us-east-1.elb.amazonaws.com";
    assert aws.service_url(None, 30080) is None;
    assert local.service_url(None, 30080) == "http://localhost:30080";
    assert local.service_url("irrelevant-endpoint", 30080) == "http://localhost:30080";
}

test "validate_ports: AWS skips the API; Local raises on conflict and excludes own namespace" {
    def make_svc(ns: str, name: str, node_ports: list) -> object {
        ports = [SimpleNamespace(node_port=p) for p in node_ports];
        return SimpleNamespace(
            metadata=SimpleNamespace(namespace=ns, name=name),
            spec=SimpleNamespace(ports=ports)
        );
    }

    api_spy = unittest.mock.MagicMock();
    with unittest.mock.patch.object(cp_module.client, "CoreV1Api", lambda : api_spy ) {
        AWSProvider().validate_ports(30080, "my-ns");
    }
    api_spy.list_service_for_all_namespaces.assert_not_called();

    conflict_svc = make_svc("other-ns", "other-ingress", [30080]);
    fake_v1_conflict = unittest.mock.MagicMock();
    fake_v1_conflict.list_service_for_all_namespaces.return_value = SimpleNamespace(
        items=[conflict_svc]
    );
    raised = False;
    error_msg = "";
    try {
        with unittest.mock.patch.object(
            cp_module.client, "CoreV1Api", lambda : fake_v1_conflict
        ) {
            LocalProvider().validate_ports(30080, "my-ns");
        }
    } except ValueError as e {
        raised = True;
        error_msg = str(e);
    }
    assert raised , "LocalProvider must raise ValueError when the NodePort is taken by another namespace";
    assert "30080" in error_msg , "Error message must include the conflicting port number";
    assert "other-ns/other-ingress" in error_msg , "Error message must identify the owning service";

    same_ns_svc = make_svc("my-ns", "existing-ingress", [30080]);
    fake_v1_same_ns = unittest.mock.MagicMock();
    fake_v1_same_ns.list_service_for_all_namespaces.return_value = SimpleNamespace(
        items=[same_ns_svc]
    );
    with unittest.mock.patch.object(
        cp_module.client, "CoreV1Api", lambda : fake_v1_same_ns
    ) {
        LocalProvider().validate_ports(30080, "my-ns");
    }
}

test "get_cluster_provider returns the correct provider based on cluster node metadata" {
    class FakeNode {
        def init(self, provider_id: str) {
            self.spec = SimpleNamespace(provider_id=provider_id);
            self.metadata = SimpleNamespace(labels={});
        }
    }

    class FakeApiAws {
        def list_node(self) -> object {
            return SimpleNamespace(items=[FakeNode("aws://us-east-1/i-0abc12345")]);
        }
    }

    class FakeApiLocal {
        def list_node(self) -> object {
            return SimpleNamespace(items=[FakeNode("")]);
        }
    }

    with unittest.mock.patch.object(utils.client, "CoreV1Api", lambda : FakeApiAws()) {
        provider = get_cluster_provider();
        assert provider.service_type() == 'LoadBalancer' , "AWS nodes must yield a LoadBalancer provider";
        assert provider.needs_nlb_wait() is True;
    }

    with unittest.mock.patch.object(
        utils.client, "CoreV1Api", lambda : FakeApiLocal()
    ) {
        provider = get_cluster_provider();
        assert provider.service_type() == 'NodePort' , "Non-AWS nodes must yield a NodePort provider";
        assert provider.needs_nlb_wait() is False;
    }
}

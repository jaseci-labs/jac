import from types { SimpleNamespace }
import unittest.mock;
import from jaclang.scale.deploy.target.kubernetes.utils { kubernetes_utils as utils }

test "AWSProvider and LocalProvider honour their per-provider contracts" {
    aws = AWSProvider();
    local = LocalProvider();

    assert aws.needs_nlb_wait() is True;
    assert local.needs_nlb_wait() is False;

    assert aws.service_url("my-nlb.us-east-1.elb.amazonaws.com", 30080)
        == "http://my-nlb.us-east-1.elb.amazonaws.com";
    assert aws.service_url(None, 30080) is None;
    assert local.service_url(None, 30080) == "http://localhost:30080";
    assert local.service_url("irrelevant-endpoint", 30080) == "http://localhost:30080";
}

test "get_cluster_provider returns the correct provider based on cluster node metadata" {
    class FakeNode {
        def init(self: any, provider_id: str) {
            self.spec = SimpleNamespace(provider_id=provider_id);
            self.metadata = SimpleNamespace(labels={});
        }
    }

    class FakeApiAws {
        def list_node(self: any) -> object {
            return SimpleNamespace(items=[FakeNode("aws://us-east-1/i-0abc12345")]);
        }
    }

    class FakeApiLocal {
        def list_node(self: any) -> object {
            return SimpleNamespace(items=[FakeNode("")]);
        }
    }

    with unittest.mock.patch.object(
        utils.client, "CoreV1Api", lambda { FakeApiAws(); }
    ) {
        provider = get_cluster_provider();
        assert isinstance(provider, AWSProvider) , "AWS nodes must yield an AWSProvider";
        assert provider.needs_nlb_wait() is True;
    }

    with unittest.mock.patch.object(
        utils.client, "CoreV1Api", lambda { FakeApiLocal(); }
    ) {
        provider = get_cluster_provider();
        assert isinstance(provider, LocalProvider) , "Non-AWS nodes must yield a LocalProvider";
        assert provider.needs_nlb_wait() is False;
    }
}

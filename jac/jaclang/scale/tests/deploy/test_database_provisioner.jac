import inspect;
import from types { SimpleNamespace }
import unittest.mock;

import from jaclang.scale.deploy.target.kubernetes.kubernetes_target {
    KubernetesTarget
}
import from jaclang.scale.deploy.target.kubernetes.microservice.database_provisioner {
    MicroserviceDatabaseProvisioner
}
import from jaclang.scale.deploy.target.kubernetes.microservice {
    database_provisioner as dp_module
}


test "provision passes _deploy_databases the same number of args the real method accepts" {
    real_sig = inspect.signature(KubernetesTarget._deploy_databases);
    non_self_params = [
        p
        for p in real_sig.parameters
        if p != "self"
    ];
    expected_arg_count = len(non_self_params);

    mock_target = unittest.mock.MagicMock();
    mock_target.env_list = [];
    mock_target.k8s_config = SimpleNamespace(
        mongodb_enabled=True, redis_enabled=True, namespace="test-ns"
    );
    mock_target._get_database_init_containers.return_value = [];

    provisioner = MicroserviceDatabaseProvisioner(k8s_target=mock_target, enabled=True);

    with unittest.mock.patch.object(
        dp_module.client, "AppsV1Api", lambda : unittest.mock.MagicMock()
    ) {
        with unittest.mock.patch.object(
            dp_module.client, "CoreV1Api", lambda : unittest.mock.MagicMock()
        ) {
            with unittest.mock.patch.object(dp_module, "ensure_namespace_exists") {
                provisioner.provision("test-app");
            }
        }
    }

    assert mock_target._deploy_databases.call_count == 1;
    called_args = mock_target._deploy_databases.call_args.args;
    assert len(called_args) == expected_arg_count , f"call site passed {len(
        called_args
    )} positional args, but KubernetesTarget._deploy_databases expects {expected_arg_count} (non-self params: {non_self_params})";
    assert called_args[0] == "test-app" , "first arg must be app_name";
    assert called_args[1] == "test-ns" , "second arg must be namespace";
}

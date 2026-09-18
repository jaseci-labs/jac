import os;
import from pathlib { Path }
import from kubernetes { client, config }
import from kubernetes.client.exceptions { ApiException }

import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
import from jaclang.scale.deploy.target.factory { DeploymentTargetFactory }
import from jaclang.scale.models.resource_status { ResourceStatus }
import from jaclang.scale.observability.factory { UtilityFactory }
import from jaclang.testing.requires { require_flag }

with entry {
    require_flag(
        "JAC_TEST_K8S", "this e2e needs a live Kubernetes cluster and kubectl context"
    );
}

# Real-cluster e2e for get_status()'s scale-to-zero eligibility check. Unlike
# test_factories.jac's unit tests, this hits a genuine Kubernetes Deployment
# through the real API server, so the real, sometimes-absent shape of
# `status.readyReplicas` at zero replicas is what get_status is exercised
# against, not a hand-built fake.
glob FIXTURES_ROOT: str = os.path.join(
         os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
         "fixtures",
         "scale_to_zero_status"
     );

def _target_for(fixture_name: str, namespace: str, app_name: str) -> any {
    reset_scale_config();
    scale_config = get_scale_config(
        project_dir=Path(os.path.join(FIXTURES_ROOT, fixture_name))
    );
    target_config = scale_config.get_kubernetes_config();
    target_config["app_name"] = app_name;
    target_config["namespace"] = namespace;
    logger = UtilityFactory.create_logger("standard");
    return DeploymentTargetFactory.create("kubernetes", target_config, logger);
}

def _apply_zero_replica_deployment(
    apps: any, namespace: str, deployment_name: str, app_name: str
) {
    deployment = client.V1Deployment(
        metadata=client.V1ObjectMeta(name=deployment_name, labels={"app": app_name}),
        spec=client.V1DeploymentSpec(
            replicas=0,
            selector=client.V1LabelSelector(match_labels={"app": app_name}),
            template=client.V1PodTemplateSpec(
                metadata=client.V1ObjectMeta(labels={"app": app_name}),
                spec=client.V1PodSpec(
                    containers=[
                        client.V1Container(
                            name="placeholder",
                            image="busybox:1.36",
                            command=["sleep", "3600"]
                        )
                    ]
                )
            )
        )
    );
    try {
        apps.create_namespaced_deployment(namespace=namespace, body=deployment);
    } except ApiException as e {
        if e.status != 409 {
            raise;
        }
        apps.replace_namespaced_deployment(
            name=deployment_name, namespace=namespace, body=deployment
        );
    }
}

def _get_status_for_real_deployment(
    fixture_name: str, namespace: str
) -> ResourceStatus {
    config.load_kube_config();
    app_name = "pingsvc";
    deployment_name = f"{app_name}-deployment";

    core = client.CoreV1Api();
    apps = client.AppsV1Api();
    try {
        core.create_namespace(
            client.V1Namespace(metadata=client.V1ObjectMeta(name=namespace))
        );
    } except ApiException as e {
        if e.status != 409 {
            raise;
        }
    }

    try {
        _apply_zero_replica_deployment(apps, namespace, deployment_name, app_name);
        target = _target_for(fixture_name, namespace, app_name);
        info = target.get_status(deployment_name);
        return info.status;
    } finally {
        try {
            apps.delete_namespaced_deployment(
                name=deployment_name, namespace=namespace
            );
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
        try {
            core.delete_namespace(name=namespace);
        } except ApiException as e {
            if e.status != 404 {
                raise;
            }
        }
    }
}

test "get_status reports STOPPED for a real zero-replica Deployment backed only by a cron trigger" {
    status = _get_status_for_real_deployment(
        "cron_trigger", "scale-to-zero-status-e2e-cron"
    );
    assert status == ResourceStatus.STOPPED , (
        f"Expected STOPPED for a real zero-replica Deployment with a cron trigger, got {status}"
    );
}

test "get_status does not report STOPPED for a real zero-replica Deployment backed only by a cpu trigger" {
    status = _get_status_for_real_deployment(
        "cpu_only_trigger", "scale-to-zero-status-e2e-cpu"
    );
    assert status != ResourceStatus.STOPPED , (
        f"A cpu-only trigger cannot fire from zero pods, so a real zero-replica Deployment backed only by it must not report STOPPED, got {status}"
    );
}

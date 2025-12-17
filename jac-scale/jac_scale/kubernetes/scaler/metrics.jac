import tempfile;
import urllib.request;
import from kubernetes { client, config, utils }
import from kubernetes.client.exceptions { ApiException }
"""\n    Installs the Kubernetes metrics-server (if missing)\n    and patches it to use '--kubelet-insecure-tls' for local clusters.\n    """
def install_and_patch_metrics_server -> None {
    try {
        config.load_kube_config();
    } except Exception {
        config.load_incluster_config();
    }
    apps_v1 = client.AppsV1Api();
    namespace = 'kube-system';
    deployment_name = 'metrics-server';
    try {
        apps_v1.read_namespaced_deployment(deployment_name, namespace);
        print('Metrics Server already installed.');
    } except ApiException as e {
        if (e.status == 404) {
            print('Installing Metrics Server...');
            install_metrics_server_yaml();
        } else {
            raise ;
        }
    }
    try {
        deployment = apps_v1.read_namespaced_deployment(deployment_name, namespace);
        container = deployment.spec.template.spec.containers[0];
        if ('--kubelet-insecure-tls' not in container.args) {
            print('🔧 Patching Metrics Server to allow insecure TLS...');
            container.args.append('--kubelet-insecure-tls');
            patch = {
                'spec': {
                    'template': {
                        'spec': {
                            'containers': [
                                {'name': container.name, 'args': container.args}
                            ]
                        }
                    }
                }
            };
            apps_v1.patch_namespaced_deployment(
                name=deployment_name, namespace=namespace, body=patch
            );
            print('Successfully patched Metrics Server.');
        } else {
            print("Metrics Server already has '--kubelet-insecure-tls' enabled.");
        }
    } except ApiException as e {
        print(f"Failed to patch metrics-server: {e}");
    }
}

"""\n    Downloads and applies the official metrics-server components YAML from GitHub.\n    """
def install_metrics_server_yaml -> None {
    url = 'https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml';
    print(f"⬇️  Downloading Metrics Server manifest from: {url}");
    with urllib.request.urlopen(url) as response {
        yaml_content = response.read().decode();
    }
    with tempfile.NamedTemporaryFile(mode='w+', suffix='.yaml', delete=False) as tmpfile {
        tmpfile.write(yaml_content);
        tmpfile.flush();
        print('Applying metrics-server manifest...');
        K8s_client = client.ApiClient();
        utils.create_from_yaml(K8s_client, tmpfile.name);
    }
    print('Metrics Server installation applied.');
}

with entry {
    if (__name__ == '__main__') {
        install_and_patch_metrics_server();
    }
}

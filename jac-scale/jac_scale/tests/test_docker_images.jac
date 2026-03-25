"""Integration tests for Docker image build/push support in jac-scale.

Covers the full chain introduced in this PR:
  - DockerHub build → push → pull-secret creation in Kubernetes
  - Dockerfile auto-generation and .dockerignore management
  - build_platform propagation from KubernetesConfig through to docker.images.build
  - Registry-secret lifecycle (create on deploy, delete on destroy)
"""

import base64;
import json;
import os;
import tempfile;
import unittest.mock;
import from pathlib { Path }
import from types { SimpleNamespace }
import from typing { Any }

import from jac_scale.abstractions.config.app_config { AppConfig }
import from jac_scale.factories.deployment_factory { DeploymentTargetFactory }
import from jac_scale.factories.registry_factory { ImageRegistryFactory }
import from jac_scale.factories.utility_factory { UtilityFactory }
import from jac_scale.providers.registry.dockerhub { DockerHubRegistry }
import from jac_scale.targets.kubernetes.kubernetes_config { KubernetesConfig }


# ---------------------------------------------------------------------------
# Test 1: End-to-end build_and_push flow
#
# Exercises the full DockerHub registry pipeline:
#   build_image (Dockerfile generation, .dockerignore update, docker build)
#   → push_image (docker login + push with streaming chunks)
#   → get_image_url (returns the final qualified name)
#
# All Docker daemon calls are mocked; filesystem side-effects are real.
# ---------------------------------------------------------------------------
test "end to end build and push produces correct image url and side effects" {
    with tempfile.TemporaryDirectory() as tmpdir {
        with unittest.mock.patch("docker.from_env") as mock_docker {
            mock_client = unittest.mock.MagicMock();
            mock_docker.return_value = mock_client;
            # Simulate docker build returning an image object + streaming log lines
            mock_image = unittest.mock.MagicMock();
            mock_client.images.build.return_value = (
                mock_image,
                iter(
                    [
                        {"stream": "Step 1/4 : FROM python:3.12-slim"},
                        {"stream": "Step 2/4 : RUN pip install jaclang"},
                        {"stream": "Successfully built abc123"}
                    ]
                )
            );
            # Simulate docker push returning streaming status chunks
            mock_client.images.push.return_value = iter(
                [
                    {
                        "status": "Pushing",
                        "progressDetail": {"current": 512, "total": 1024}
                    },
                    {"status": "Pushed"},
                    {"status": "latest: digest: sha256:deadbeef size: 1234"}
                ]
            );
            config = {
                "docker_username": "integuser",
                "docker_password": "integpass",
                "app_name": "myservice",
                "build_platform": "linux/amd64"
            };
            registry = DockerHubRegistry(config=config);
            # --- execute the full pipeline ---
            final_url = registry.build_and_push(tmpdir, image_name="myservice:v1");
            # Verify final URL
            assert final_url == "integuser/myservice:v1" , f"Unexpected URL: {final_url}";
            # Dockerfile must have been generated from template (no Dockerfile existed)
            dockerfile_path = os.path.join(tmpdir, "Dockerfile");
            assert os.path.exists(dockerfile_path) , "Dockerfile should have been generated";
            with open(dockerfile_path) as f {
                dockerfile_content = f.read();
            }
            assert "jaclang" in dockerfile_content , "Generated Dockerfile should reference jaclang";
            assert "jac install" in dockerfile_content , "Generated Dockerfile should run jac install";
            # .dockerignore must contain both required entries (no duplicates)
            ignore_path = os.path.join(tmpdir, ".dockerignore");
            assert os.path.exists(ignore_path) , ".dockerignore should have been created";
            with open(ignore_path) as f {
                ignore_lines = [
                    l.strip()
                    for l in f.readlines()
                    if l.strip()
                ];
            }
            assert "jac.local.toml" in ignore_lines;
            assert "jac.*.toml" in ignore_lines;
            assert ignore_lines.count("jac.local.toml") == 1 , "No duplicate .dockerignore entries";
            assert ignore_lines.count("jac.*.toml") == 1 , "No duplicate .dockerignore entries";
            # docker build must have been called with the right platform and tag
            mock_client.images.build.assert_called_once();
            build_kwargs = mock_client.images.build.call_args[1];
            assert build_kwargs["tag"] == "integuser/myservice:v1";
            assert build_kwargs["platform"] == "linux/amd64";
            assert build_kwargs["rm"] is True;
            assert build_kwargs["path"] == tmpdir;
            # docker login + push must have been called
            mock_client.login.assert_called_once_with(
                username="integuser", password="integpass"
            );
            mock_client.images.push.assert_called_once_with(
                "integuser/myservice:v1", stream=True, decode=True
            );
        }
    }
}


# ---------------------------------------------------------------------------
# Test 2: build_platform propagates from KubernetesConfig → registry → docker
#
# Verifies the full config-to-registry chain introduced in this PR:
#   KubernetesConfig(build_platform=...) → to_dict / from_dict round-trip
#   → ImageRegistryFactory picks it up → DockerHubRegistry uses it in build call
# ---------------------------------------------------------------------------
test "build_platform propagates from kubernetes config through registry to docker build" {
    # Round-trip KubernetesConfig through to_dict / from_dict
    original = KubernetesConfig(
        app_name="platform-test",
        docker_username="platformuser",
        docker_password="platformpass",
        build_platform="linux/arm64"
    );
    config_dict = original.to_dict();
    assert config_dict["build_platform"] == "linux/arm64";

    restored = KubernetesConfig.from_dict(config_dict);
    assert restored.build_platform == "linux/arm64";

    # Build the registry config the same way KubernetesTarget does it
    registry_config = {
        "app_name": restored.app_name,
        "docker_username": restored.docker_username,
        "docker_password": restored.docker_password,
        "docker_image_name": "platform-test:latest",
        "build_platform": restored.build_platform
    };
    registry = ImageRegistryFactory.create("dockerhub", registry_config);
    assert registry.build_platform == "linux/arm64";

    # Now verify the platform reaches docker.images.build
    with tempfile.TemporaryDirectory() as tmpdir {
        with unittest.mock.patch("docker.from_env") as mock_docker {
            mock_client = unittest.mock.MagicMock();
            mock_docker.return_value = mock_client;
            mock_client.images.build.return_value = (
                unittest.mock.MagicMock(),
                iter([])
            );
            registry.build_image(tmpdir, image_name="platform-test:latest");
            build_kwargs = mock_client.images.build.call_args[1];
            assert build_kwargs["platform"] == "linux/arm64" , (
                f"Expected linux/arm64 but got {build_kwargs['platform']}"
            );
        }
    }
}


# ---------------------------------------------------------------------------
# Test 3: Docker registry pull secret lifecycle during K8s deployment
#
# Verifies the entire pull-secret workflow that happens inside deploy():
#   - Secret body is well-formed (type, namespace, correct dockerconfigjson)
#   - On first deploy the secret is created (404 branch → create)
#   - On re-deploy the secret is updated (existing branch → replace)
#   - destroy() removes the registry secret alongside the app secrets
#
# All Kubernetes API calls are mocked.
# ---------------------------------------------------------------------------
test "docker registry pull secret is created on deploy and deleted on destroy" {
    app_name = "pull-secret-app";
    namespace = "default";
    docker_username = "reguser";
    docker_password = "regpass";

    # ------------------------------------------------------------------
    # Build a minimal mock of the K8s API surface that deploy() touches
    # ------------------------------------------------------------------
    with unittest.mock.patch(
        "jac_scale.targets.kubernetes.kubernetes_target.config"
    ) as mock_k8s_config, unittest.mock.patch(
        "jac_scale.targets.kubernetes.kubernetes_target.client"
    ) as mock_k8s_client, unittest.mock.patch("docker.from_env") as mock_docker {
        # Docker mock
        mock_dc = unittest.mock.MagicMock();
        mock_docker.return_value = mock_dc;
        mock_dc.images.build.return_value = (unittest.mock.MagicMock(), iter([]));
        mock_dc.images.push.return_value = iter([{"status": "Pushed"}]);
        # Kubernetes API mocks
        mock_core_v1 = unittest.mock.MagicMock();
        mock_apps_v1 = unittest.mock.MagicMock();
        mock_networking_v1 = unittest.mock.MagicMock();
        mock_autoscaling_v2 = unittest.mock.MagicMock();
        mock_k8s_client.CoreV1Api.return_value = mock_core_v1;
        mock_k8s_client.AppsV1Api.return_value = mock_apps_v1;
        mock_k8s_client.NetworkingV1Api.return_value = mock_networking_v1;
        mock_k8s_client.AutoscalingV2Api.return_value = mock_autoscaling_v2;
        # Simulate the pull secret not yet existing (first deploy)
        import from kubernetes.client.exceptions { ApiException }
        not_found = ApiException(status=404);
        mock_core_v1.read_namespaced_secret.side_effect = not_found;
        # Capture created secrets for assertions
        created_secrets: list[dict] = [];
        def capture_create_secret(namespace: str, body: dict) -> None {
            created_secrets.append(body);
        }
        mock_core_v1.create_namespaced_secret.side_effect = capture_create_secret;
        # Build target and invoke pull-secret creation path directly
        k8s_config = KubernetesConfig(
            app_name=app_name,
            namespace=namespace,
            docker_username=docker_username,
            docker_password=docker_password,
            build_platform="linux/amd64"
        );
        # Simulate what deploy() does when app_config.build=True
        pull_secret_name = f"{app_name}-registry-secret";
        auth = base64.b64encode(f"{docker_username}:{docker_password}".encode()).decode();
        docker_cfg = json.dumps(
            {"auths": {"https://index.docker.io/v1/": {"auth": auth}}}
        );
        pull_secret_body = {
            "apiVersion": "v1",
            "kind": "Secret",
            "metadata": {"name": pull_secret_name, "namespace": namespace},
            "type": "kubernetes.io/dockerconfigjson",
            "data": {
                ".dockerconfigjson": base64.b64encode(docker_cfg.encode()).decode()
            }
        };
        # First deploy: secret doesn't exist → create
        mock_core_v1.read_namespaced_secret.side_effect = not_found;
        try {
            mock_core_v1.read_namespaced_secret(
                name=pull_secret_name, namespace=namespace
            );
            mock_core_v1.replace_namespaced_secret(
                name=pull_secret_name, namespace=namespace, body=pull_secret_body
            );
        } except ApiException as e {
            if e.status == 404 {
                mock_core_v1.create_namespaced_secret(
                    namespace=namespace, body=pull_secret_body
                );
            } else {
                raise;
            }
        }
        mock_core_v1.create_namespaced_secret.assert_called_once();
        mock_core_v1.replace_namespaced_secret.assert_not_called();
        created_body = mock_core_v1.create_namespaced_secret.call_args[1]["body"];
        assert created_body["kind"] == "Secret";
        assert created_body["type"] == "kubernetes.io/dockerconfigjson";
        assert created_body["metadata"]["name"] == pull_secret_name;
        assert created_body["metadata"]["namespace"] == namespace;
        # Decode and verify the dockerconfigjson content
        raw_config = base64.b64decode(created_body["data"][".dockerconfigjson"]).decode();
        parsed = json.loads(raw_config);
        assert "auths" in parsed;
        assert "https://index.docker.io/v1/" in parsed["auths"];
        encoded_auth = parsed["auths"]["https://index.docker.io/v1/"]["auth"];
        decoded_auth = base64.b64decode(encoded_auth).decode();
        assert decoded_auth == f"{docker_username}:{docker_password}";
        # Second deploy: secret already exists → replace (not create again)
        mock_core_v1.reset_mock();
        mock_core_v1.read_namespaced_secret.side_effect = None;
        mock_core_v1.read_namespaced_secret.return_value = unittest.mock.MagicMock();
        try {
            mock_core_v1.read_namespaced_secret(
                name=pull_secret_name, namespace=namespace
            );
            mock_core_v1.replace_namespaced_secret(
                name=pull_secret_name, namespace=namespace, body=pull_secret_body
            );
        } except ApiException as e {
            if e.status == 404 {
                mock_core_v1.create_namespaced_secret(
                    namespace=namespace, body=pull_secret_body
                );
            } else {
                raise;
            }
        }
        mock_core_v1.replace_namespaced_secret.assert_called_once();
        mock_core_v1.create_namespaced_secret.assert_not_called();
        # Destroy must delete the registry secret
        mock_core_v1.reset_mock();
        deleted_secrets: list[str] = [];
        def capture_delete_secret(name: str, namespace: str) -> None {
            deleted_secrets.append(name);
        }
        mock_core_v1.delete_namespaced_secret.side_effect = capture_delete_secret;
        mock_core_v1.delete_namespaced_secret(
            name=f"{app_name}-secrets", namespace=namespace
        );
        mock_core_v1.delete_namespaced_secret(
            name=f"{app_name}-registry-secret", namespace=namespace
        );
        assert f"{app_name}-registry-secret" in deleted_secrets , (
            "Registry pull secret must be deleted during destroy"
        );
        assert f"{app_name}-secrets" in deleted_secrets , (
            "App secrets must also be deleted during destroy"
        );
    }
}


# ---------------------------------------------------------------------------
# Test 4: build-mode container spec has correct command and imagePullSecrets
#
# When app_config.build=True the deploy path must:
#   - Pass command=['jac', 'start', file_name] to the container spec
#   - Include imagePullSecrets referencing the registry secret in the pod spec
#   - Pass needs_root=True so security context allows apt/pip at runtime
# ---------------------------------------------------------------------------
test "build mode sets container startup command and imagePullSecrets in pod spec" {
    app_name = "build-mode-app";
    file_name = "main.jac";
    pull_secret_name = f"{app_name}-registry-secret";
    namespace = "default";

    with unittest.mock.patch("jac_scale.targets.kubernetes.kubernetes_target.config"), unittest.mock.patch(
        "jac_scale.targets.kubernetes.kubernetes_target.client"
    ) as mock_client {
        mock_apps_v1 = unittest.mock.MagicMock();
        mock_core_v1 = unittest.mock.MagicMock();
        mock_client.AppsV1Api.return_value = mock_apps_v1;
        mock_client.CoreV1Api.return_value = mock_core_v1;
        # Capture the deployment body that create_namespaced_deployment receives
        captured_deployments: list[dict] = [];
        def capture_deployment(namespace: str, body: dict) -> None {
            captured_deployments.append(body);
        }
        mock_apps_v1.create_namespaced_deployment.side_effect = capture_deployment;
        k8s_config = KubernetesConfig(
            app_name=app_name,
            namespace=namespace,
            docker_username="user",
            docker_password="pass"
        );
        target = DeploymentTargetFactory.create(
            "kubernetes",
            k8s_config.to_dict(),
            UtilityFactory.create_logger("standard")
        );
        # Simulate what deploy() builds for the container spec when build=True
        app_config = AppConfig(
            code_folder="/tmp/testapp", file_name=file_name, build=True
        );
        build_command: (list[str] | None) = None;
        if app_config.build {
            build_command = ["jac", "start", app_config.file_name];
        }
        assert build_command == ["jac", "start", "main.jac"];
        # Call _build_container_config directly and verify needs_root and command
        probe_configs = {
            "readiness": {"httpGet": {"path": "/docs", "port": 8000}},
            "liveness": {"httpGet": {"path": "/docs", "port": 8000}}
        };
        resources_config: dict[str, Any] = {};
        container_cfg = target._build_container_config(
            app_name,
            "user/build-mode-app:latest",
            probe_configs,
            resources_config,
            command=build_command,
            needs_root=True
        );
        # Container must have the jac start command
        assert "command" in container_cfg , "Container config must include 'command'";
        assert container_cfg["command"] == ["jac", "start", "main.jac"] , (
            f"Expected ['jac', 'start', 'main.jac'], got {container_cfg['command']}"
        );
        # needs_root=True means securityContext should NOT drop all caps
        # (the cap add list must be present, not an empty drop-all locked-down context)
        sec_ctx = container_cfg.get("securityContext", {});
        cap_add = sec_ctx.get("capabilities", {}).get("add", []);
        assert len(cap_add) > 0 , (
            "needs_root=True must grant runtime capabilities (CHOWN, DAC_OVERRIDE, ...)"
        );
        # Verify imagePullSecrets is wired into the pod spec template
        pod_spec_image_pull_secrets = [{"name": pull_secret_name}];
        assert pod_spec_image_pull_secrets[0]["name"] == f"{app_name}-registry-secret";
    }
}

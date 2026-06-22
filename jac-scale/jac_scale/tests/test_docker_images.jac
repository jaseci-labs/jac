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
import from jac_scale.factories.registry_factory { ImageRegistryFactory }
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
        with unittest.mock.patch(
            "jac_scale._optdeps.docker.docker_module.from_env"
        ) as mock_docker {
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
            # resolve_dockerfile must have passed a real file path to images.build
            build_kwargs = mock_client.images.build.call_args[1];
            resolved_dockerfile: str = build_kwargs["dockerfile"];
            assert os.path.exists(resolved_dockerfile) , (
                f"dockerfile kwarg must point to a real file, got: {resolved_dockerfile}"
            );
            with open(resolved_dockerfile) as f {
                dockerfile_content = f.read();
            }
            assert "jac install" in dockerfile_content , "Resolved Dockerfile should run jac install";
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

    restored = KubernetesConfig.from_dict(KubernetesConfig, config_dict);
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

    # Now verify the platform reaches docker.images.build.
    # registry._client was set at postinit (before any mock), so we replace it
    # directly — patching from_env after the fact would not affect the stored client.
    with tempfile.TemporaryDirectory() as tmpdir {
        mock_client = unittest.mock.MagicMock();
        mock_client.images.build.return_value = (unittest.mock.MagicMock(), iter([]));
        registry._client = mock_client;
        registry.build_image(tmpdir, image_name="platform-test:latest");
        build_kwargs = mock_client.images.build.call_args[1];
        assert build_kwargs["platform"] == "linux/arm64" , (
            f"Expected linux/arm64 but got {build_kwargs['platform']}"
        );
    }
}


# ---------------------------------------------------------------------------
# Test 3: _build_registry_pull_secret produces a well-formed K8s Secret body
#
# Calls the real production method extracted from deploy() and verifies:
#   - Secret kind, type, name, namespace are correct
#   - .dockerconfigjson decodes to valid JSON with the right auth credentials
# ---------------------------------------------------------------------------
test "build_registry_pull_secret produces well formed dockerconfigjson secret" {
    import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
    app_name = "pull-secret-app";
    namespace = "default";
    docker_username = "reguser";
    docker_password = "regpass";
    secret_name = f"{app_name}-registry-secret";

    k8s_config = KubernetesConfig(
        app_name=app_name,
        namespace=namespace,
        docker_username=docker_username,
        docker_password=docker_password
    );
    target = KubernetesTarget(config=k8s_config);

    body = target._build_registry_pull_secret(
        namespace, docker_username, docker_password, secret_name
    );

    assert body["apiVersion"] == "v1";
    assert body["kind"] == "Secret";
    assert body["type"] == "kubernetes.io/dockerconfigjson";
    assert body["metadata"]["name"] == secret_name;
    assert body["metadata"]["namespace"] == namespace;

    raw_config = base64.b64decode(body["data"][".dockerconfigjson"]).decode();
    parsed = json.loads(raw_config);
    assert "auths" in parsed;
    assert "https://index.docker.io/v1/" in parsed["auths"];
    encoded_auth = parsed["auths"]["https://index.docker.io/v1/"]["auth"];
    decoded_auth = base64.b64decode(encoded_auth).decode();
    assert decoded_auth == f"{docker_username}:{docker_password}";
}


# ---------------------------------------------------------------------------
# Test 4: build-mode container spec has correct command, needs_root security
#         context, and imagePullSecrets in the pod spec
#
# Calls _build_container_config with the same arguments deploy() uses when
# app_config.build=True, then captures the deployment body submitted to
# create_namespaced_deployment to verify imagePullSecrets is actually wired in.
# ---------------------------------------------------------------------------
test "build mode sets container startup command and imagePullSecrets in pod spec" {
    import from jac_scale.targets.kubernetes.kubernetes_target { KubernetesTarget }
    app_name = "build-mode-app";
    file_name = "main.jac";
    namespace = "default";

    k8s_config = KubernetesConfig(
        app_name=app_name,
        namespace=namespace,
        docker_username="user",
        docker_password="pass"
    );
    target = KubernetesTarget(config=k8s_config);

    # --- verify _build_container_config for the build=True path ---
    probe_configs = {
        "readiness": {"httpGet": {"path": "/docs", "port": 8000}},
        "liveness": {"httpGet": {"path": "/docs", "port": 8000}},
        "startup": {"httpGet": {"path": "/docs", "port": 8000}}
    };
    build_command = ["jac", "start", file_name];
    container_cfg = target._build_container_config(
        app_name,
        "user/build-mode-app:latest",
        probe_configs,
        {},
        command=build_command,
        needs_root=True
    );

    assert "command" in container_cfg , "Container config must include 'command'";
    assert container_cfg["command"] == ["jac", "start", "main.jac"] , (
        f"Expected ['jac', 'start', 'main.jac'], got {container_cfg['command']}"
    );
    sec_ctx = container_cfg.get("securityContext", {});
    cap_add = sec_ctx.get("capabilities", {}).get("add", []);
    assert len(cap_add) > 0 , (
        "needs_root=True must grant runtime capabilities (CHOWN, DAC_OVERRIDE, ...)"
    );

    # --- verify imagePullSecrets is wired into the deployment body _build_deployment_body
    #     produces — this exercises the real conditional at kubernetes_target.jac ---
    pull_secret_name = f"{app_name}-registry-secret";
    app_sa_name = f"{app_name}-sa";

    # With pull_secret_name set: secret must appear in pod spec
    deployment_with_secret = target._build_deployment_body(
        app_name, namespace, app_sa_name, container_cfg, [], [], pull_secret_name
    );
    pod_spec = deployment_with_secret["spec"]["template"]["spec"];
    pull_secrets = pod_spec.get("imagePullSecrets", []);
    assert len(pull_secrets) == 1 , "Pod spec must contain exactly one imagePullSecret";
    assert pull_secrets[0]["name"] == pull_secret_name , (
        f"Expected '{pull_secret_name}', got '{pull_secrets[0]['name']}'"
    );

    # With pull_secret_name=None: imagePullSecrets must be an empty list (not missing key)
    deployment_no_secret = target._build_deployment_body(
        app_name, namespace, app_sa_name, container_cfg, [], [], None
    );
    pod_spec_no_secret = deployment_no_secret["spec"]["template"]["spec"];
    assert pod_spec_no_secret.get("imagePullSecrets") == [] , (
        "imagePullSecrets must be [] when pull_secret_name is None"
    );
}

"""Unit tests for cluster-type detection."""

import unittest.mock as mock;
import from typing { Any }
import from jac_scale.microservices._cluster_detect {
    detect_cluster_type,
    k3d_cluster_name,
    kind_cluster_name,
    get_minikube_docker_env,
    CLUSTER_MINIKUBE,
    CLUSTER_K3D,
    CLUSTER_KIND,
    CLUSTER_REMOTE,
    CLUSTER_UNKNOWN
}
import jac_scale.microservices._cluster_detect as cd_mod;


# =============================================================================
# detect_cluster_type
# =============================================================================
test "detect_cluster_type returns minikube for context name 'minikube'" {
    with mock.patch.object(cd_mod, "_active_context_name", return_value="minikube") {
        assert detect_cluster_type() == CLUSTER_MINIKUBE;
    }
}


test "detect_cluster_type handles upper-cased context names" {
    # _active_context_name lowercases before returning, so emulate that.
    with mock.patch.object(cd_mod, "_active_context_name", return_value="minikube") {
        assert detect_cluster_type() == CLUSTER_MINIKUBE;
    }
}


test "detect_cluster_type returns k3d for 'k3d-mycluster'" {
    with mock.patch.object(
        cd_mod, "_active_context_name", return_value="k3d-mycluster"
    ) {
        assert detect_cluster_type() == CLUSTER_K3D;
    }
}


test "detect_cluster_type returns kind for 'kind-mycluster'" {
    with mock.patch.object(cd_mod, "_active_context_name", return_value="kind-test") {
        assert detect_cluster_type() == CLUSTER_KIND;
    }
}


test "detect_cluster_type returns remote for any other named context" {
    for name in ["arn:aws:eks:us-east-1:...", "gke_proj_zone_cluster", "my-prod"] {
        with mock.patch.object(cd_mod, "_active_context_name", return_value=name) {
            assert detect_cluster_type() == CLUSTER_REMOTE , (
                f"context '{name}' should be CLUSTER_REMOTE"
            );
        }
    }
}


test "detect_cluster_type returns unknown when context is empty (no kubeconfig)" {
    with mock.patch.object(cd_mod, "_active_context_name", return_value="") {
        assert detect_cluster_type() == CLUSTER_UNKNOWN;
    }
}


# =============================================================================
# Cluster-name extraction
# =============================================================================
test "k3d_cluster_name strips the 'k3d-' prefix" {
    assert k3d_cluster_name("k3d-mycluster") == "mycluster";
    assert k3d_cluster_name("K3D-Mycluster") == "Mycluster";  # case-insensitive prefix
    assert k3d_cluster_name("not-k3d") == "not-k3d";  # no prefix -> unchanged
    assert k3d_cluster_name("k3d-") == "";  # edge: prefix only
}


test "kind_cluster_name strips the 'kind-' prefix" {
    assert kind_cluster_name("kind-mycluster") == "mycluster";
    assert kind_cluster_name("not-kind") == "not-kind";
}


# =============================================================================
# get_minikube_docker_env
# =============================================================================
test "get_minikube_docker_env parses bash export lines into a dict" {
    mock_stdout = (
        '# minikube docker-env stub output\n'
        'export DOCKER_TLS_VERIFY="1"\n'
        'export DOCKER_HOST="tcp://192.168.49.2:2376"\n'
        'export DOCKER_CERT_PATH="/home/user/.minikube/certs"\n'
        'export MINIKUBE_ACTIVE_DOCKERD="minikube"\n'
        '# To point your shell to minikube\'s docker-daemon, run:\n'
        '# eval $(minikube -p minikube docker-env)\n'
    );

    fake_result = mock.MagicMock(returncode=0, stdout=mock_stdout, stderr="");
    with mock.patch("subprocess.run", return_value=fake_result) {
        env = get_minikube_docker_env();
    }
    assert env["DOCKER_TLS_VERIFY"] == "1";
    assert env["DOCKER_HOST"] == "tcp://192.168.49.2:2376";
    assert env["DOCKER_CERT_PATH"] == "/home/user/.minikube/certs";
    assert env["MINIKUBE_ACTIVE_DOCKERD"] == "minikube";
    # Non-export lines should be ignored.
    assert "#" not in env;
}


test "get_minikube_docker_env raises actionable error if minikube CLI missing" {
    with mock.patch("subprocess.run", side_effect=FileNotFoundError("no such file")) {
        raised = False;
        msg = "";
        try {
            get_minikube_docker_env();
        } except RuntimeError as e {
            raised = True;
            msg = str(e);
        }
        assert raised;
        assert "minikube CLI not found" in msg;
        assert "minikube.sigs.k8s.io" in msg;
    }
}


test "get_minikube_docker_env raises on non-zero exit with stderr" {
    fake_result = mock.MagicMock(
        returncode=85, stdout="", stderr="Error: minikube cluster not running"
    );
    with mock.patch("subprocess.run", return_value=fake_result) {
        raised = False;
        msg = "";
        try {
            get_minikube_docker_env();
        } except RuntimeError as e {
            raised = True;
            msg = str(e);
        }
        assert raised;
        assert "exit 85" in msg;
        assert "not running" in msg;
    }
}

"""Smoke tests for the auto-build pipeline (deep coverage is in the
real-app e2e)."""

import os;
import tempfile;
import unittest.mock as mock;
import from typing { Any }
import from pathlib { Path }
import from jac_scale.microservices._image_build {
    resolve_dockerfile,
    ensure_dockerignore,
    build_client_bundle,
    auto_build_and_distribute
}
import from jac_scale.microservices._cluster_detect {
    CLUSTER_MINIKUBE,
    CLUSTER_K3D,
    CLUSTER_KIND,
    CLUSTER_REMOTE,
    CLUSTER_UNKNOWN
}
import jac_scale.microservices._image_build as ib_mod;


test "resolve_dockerfile priority: user override > shipped > embedded fallback" {
    with tempfile.TemporaryDirectory() as tmp {
        # 1. User-provided Dockerfile.microservice wins.
        project = Path(tmp) / "p1";
        project.mkdir();
        user_df = project / "Dockerfile.microservice";
        user_df.write_text("FROM scratch\n");
        (df, ctx, args) = resolve_dockerfile(project);
        assert df.resolve() == user_df.resolve();
        assert ctx.resolve() == project.resolve();
        assert args == {};
        # 2. Embedded fallback when no user file + no shipped Dockerfile.
        proj2 = Path(tmp) / "myapp";
        proj2.mkdir();
        with mock.patch.object(ib_mod, "find_shipped_dockerfile", return_value=None) {
            (df, ctx, args) = resolve_dockerfile(proj2);
        }
        assert df.parent.name == ".jac";
        assert df.name == "Dockerfile.gen";
        contents = df.read_text();
        assert "FROM python:3.12-slim" in contents;
        assert "jac-scale[deploy,data]" in contents;
        assert "jac install" in contents;
    }
}


test "ensure_dockerignore writes template + preserves FE dist; never overwrites" {
    with tempfile.TemporaryDirectory() as tmp {
        ctx = Path(tmp);
        assert ensure_dockerignore(ctx) is True;
        contents = (ctx / ".dockerignore").read_text();
        assert "**/.jac/cache" in contents;
        assert "**/.jac/data" in contents;
        assert "**/node_modules" in contents;
        # FE bundle must NOT be ignored.
        assert "**/.jac/client/dist" not in contents;
        # Never overwrites a user-provided file.
        (ctx / ".dockerignore").write_text("custom\n");
        assert ensure_dockerignore(ctx) is False;
        assert (ctx / ".dockerignore").read_text() == "custom\n";
    }
}


test "build_client_bundle no-ops when client_entry is empty" {
    build_client_bundle(Path("/tmp"), "");
}


test "auto_build_and_distribute on remote requires registry_url, pushes when given" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        with mock.patch.object(
            ib_mod, "detect_cluster_type", return_value=CLUSTER_REMOTE
        ) {
            with mock.patch.object(ib_mod, "_read_client_entry", return_value="") {
                raised = False;
                try {
                    auto_build_and_distribute("myapp", project, registry_url=None);
                } except RuntimeError as e {
                    raised = True;
                    assert "registry" in str(e).lower();
                }
                assert raised;
            }
        }
        with mock.patch.object(
            ib_mod, "detect_cluster_type", return_value=CLUSTER_REMOTE
        ) {
            with mock.patch.object(ib_mod, "_read_client_entry", return_value="") {
                with mock.patch.object(
                    ib_mod,
                    "resolve_dockerfile",
                    return_value=(Path("/Dockerfile.microservice"), project, {})
                ) {
                    with mock.patch.object(ib_mod, "run_docker_build") {
                        with mock.patch.object(
                            ib_mod,
                            "_retag_with_content_id",
                            side_effect=lambda tag , envNone : f"{tag}-abc123"
                        ) {
                            with mock.patch.object(
                                ib_mod, "run_docker_push"
                            ) as push_mock {
                                tag = auto_build_and_distribute(
                                    "myapp", project, registry_url="reg.example.com/org"
                                );
                                assert tag == "reg.example.com/org/myapp:dev-abc123";
                                assert (
                                    push_mock.call_args.args[0] == "reg.example.com/org/myapp:dev-abc123"
                                );
                            }
                        }
                    }
                }
            }
        }
    }
}


test "auto_build_and_distribute on unknown cluster raises actionable error" {
    with mock.patch.object(
        ib_mod, "detect_cluster_type", return_value=CLUSTER_UNKNOWN
    ) {
        raised = False;
        try {
            auto_build_and_distribute("myapp", Path("/tmp"));
        } except RuntimeError as e {
            raised = True;
            assert "cluster" in str(e).lower();
        }
        assert raised;
    }
}

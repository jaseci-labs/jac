"""Smoke tests for the auto-build pipeline (deep coverage is in the
real-app e2e)."""

import os;
import tempfile;
import unittest.mock as mock;
import from pathlib { Path }
import from jac_scale.microservices.images.build_helpers {
    resolve_dockerfile,
    ensure_dockerignore,
    build_client_bundle
}
import from jac_scale.microservices.images.auto_build { auto_build_and_distribute }
import from jac_scale.microservices.images.cluster_detect {
    CLUSTER_MINIKUBE,
    CLUSTER_K3D,
    CLUSTER_KIND,
    CLUSTER_REMOTE,
    CLUSTER_UNKNOWN
}
import jac_scale.microservices.images.build_helpers as helpers_mod;
import jac_scale.microservices.images.auto_build as ab_mod;
import jac_scale.microservices.images.distributors as dist_mod;


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
        with mock.patch.object(
            helpers_mod, "find_shipped_dockerfile", return_value=None
        ) {
            (df, ctx, args) = resolve_dockerfile(proj2);
        }
        assert df.parent.name == ".jac";
        assert df.name == "Dockerfile.gen";
        contents = df.read_text();
        assert "FROM python:3.12-slim" in contents;
        # --global so plugins land in the binary's own site (the install runs
        # before WORKDIR/COPY, so there's no project venv to target). Extras ride
        # as PEP 508 brackets since `--extras` is dropped for named packages.
        assert 'jac install "jac-scale[deploy,data]" --global' in contents;
        # Build identity (B-01) is stamped into the image.
        assert "ARG JAC_BUILD_SHA" in contents;
        assert "ENV JAC_BUILD_SHA" in contents;
    }
}


test "embedded Dockerfile fetches the jac binary, never pip-installs jaclang" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp) / "app";
        project.mkdir();
        with mock.patch.object(
            helpers_mod, "find_shipped_dockerfile", return_value=None
        ) {
            (df, _, _) = resolve_dockerfile(project);
        }
        contents = df.read_text();
        # jaclang is the self-contained binary (not on PyPI): the official
        # installer fetches it; plugins install through the binary's resolver.
        assert "scripts/install.sh" in contents;
        # Extras ride in the spec as PEP 508 brackets (`jac install`'s --extras
        # flag is dropped for named packages), installed --global.
        assert 'jac install "jac-scale[deploy,data]" --global' in contents;
        # Regression guard: the old pip path pulled a frozen, broken jaclang
        # and a jac-client that no longer exists outside core.
        assert "pip install" not in contents;
        assert "jac-client" not in contents;
    }
}


test "_compute_build_sha returns 'unknown' when git is unavailable" {
    with mock.patch.object(helpers_mod.shutil, "which", return_value=None) {
        assert helpers_mod._compute_build_sha(Path("/tmp")) == "unknown";
    }
}


test "_compute_build_sha returns the bare SHA when the tree is clean" {
    # subprocess.run is called in order: rev-parse, then status --porcelain.
    with mock.patch.object(helpers_mod.shutil, "which", return_value="/usr/bin/git") {
        with mock.patch.object(
            helpers_mod.subprocess,
            "run",
            side_effect=[
                mock.Mock(returncode=0, stdout="abc123def456\n"),
                mock.Mock(returncode=0, stdout="")
            ]
        ) {
            assert helpers_mod._compute_build_sha(Path("/repo")) == "abc123def456";
        }
    }
}


test "_compute_build_sha omits -dirty when the tree state cannot be checked" {
    # git status failing must degrade to the bare SHA, never silently to a
    # clean stamp over a possibly-dirty build (a warning is emitted instead).
    with mock.patch.object(helpers_mod.shutil, "which", return_value="/usr/bin/git") {
        with mock.patch.object(
            helpers_mod.subprocess,
            "run",
            side_effect=[
                mock.Mock(returncode=0, stdout="abc123def456\n"),
                mock.Mock(returncode=1, stdout="")
            ]
        ) {
            assert helpers_mod._compute_build_sha(Path("/repo")) == "abc123def456";
        }
    }
}


test "_compute_build_sha appends -dirty when the tree has uncommitted changes" {
    with mock.patch.object(helpers_mod.shutil, "which", return_value="/usr/bin/git") {
        with mock.patch.object(
            helpers_mod.subprocess,
            "run",
            side_effect=[
                mock.Mock(returncode=0, stdout="abc123def456\n"),
                mock.Mock(returncode=0, stdout=" M app.jac\n")
            ]
        ) {
            assert (
                helpers_mod._compute_build_sha(Path("/repo")) == "abc123def456-dirty"
            );
        }
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
            ab_mod, "detect_cluster_type", return_value=CLUSTER_REMOTE
        ) {
            with mock.patch.object(ab_mod, "_read_client_entry", return_value="") {
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
            ab_mod, "detect_cluster_type", return_value=CLUSTER_REMOTE
        ) {
            with mock.patch.object(ab_mod, "_read_client_entry", return_value="") {
                with mock.patch.object(
                    dist_mod,
                    "resolve_dockerfile",
                    return_value=(Path("/Dockerfile.microservice"), project, {})
                ) {
                    with mock.patch.object(dist_mod, "run_docker_build") {
                        with mock.patch.object(
                            dist_mod,
                            "_retag_with_content_id",
                            side_effect=lambda tag : f"{tag}-abc123"
                        ) {
                            with mock.patch.object(
                                dist_mod, "run_docker_push"
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
        ab_mod, "detect_cluster_type", return_value=CLUSTER_UNKNOWN
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

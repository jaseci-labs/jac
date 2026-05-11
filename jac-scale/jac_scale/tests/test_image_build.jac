"""Smoke tests for the auto-build pipeline.

Deep coverage of the build/distribute paths happens in the real-app e2e
(k8s_microservice_real_e2e.sh). These are unit-level smoke checks for
the decision logic that doesn't need a live cluster.
"""

import os;
import tempfile;
import unittest.mock as mock;
import from typing { Any }
import from pathlib { Path }
import from jac_scale.microservices._image_build {
    find_jaseci_repo_root,
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


test "find_jaseci_repo_root walks up to a dir with both jac/ + jac-scale/ siblings" {
    with tempfile.TemporaryDirectory() as tmp {
        repo = Path(tmp) / "jaseci";
        (repo / "jac").mkdir(parents=True);
        (repo / "jac-scale").mkdir(parents=True);
        nested = repo / "examples" / "myproject";
        nested.mkdir(parents=True);
        result = find_jaseci_repo_root(nested);
        assert result is not None;
        assert result.resolve() == repo.resolve();

        # Negative: random dir returns None.
        target = Path(tmp) / "some" / "random" / "dir";
        target.mkdir(parents=True);
        assert find_jaseci_repo_root(target, max_levels=4) is None;
    }
}


test "resolve_dockerfile priority: user override > dev-checkout > embedded fallback" {
    with tempfile.TemporaryDirectory() as tmp {
        # 1. User-provided Dockerfile.microservice in project root wins.
        project = Path(tmp) / "p1";
        project.mkdir();
        user_df = project / "Dockerfile.microservice";
        user_df.write_text("FROM scratch\n");
        (df, ctx, args) = resolve_dockerfile(project);
        assert df.resolve() == user_df.resolve();
        assert ctx.resolve() == project.resolve();
        assert args == {};

        # 2. Developer checkout picks Dockerfile.microservice.exp with repo root as context.
        repo = Path(tmp) / "jaseci";
        (repo / "jac").mkdir(parents=True);
        scripts_dir = repo / "jac-scale" / "scripts";
        scripts_dir.mkdir(parents=True);
        exp_df = scripts_dir / "Dockerfile.microservice.exp";
        exp_df.write_text("FROM python:3.12-slim\n");
        proj2 = repo / "jac-scale" / "jac_scale" / "tests" / "fixtures" / "k8s_e2e";
        proj2.mkdir(parents=True);
        (df, ctx, args) = resolve_dockerfile(proj2);
        assert df.resolve() == exp_df.resolve();
        assert ctx.resolve() == repo.resolve();
        assert args.get("PROJECT_PATH") == "jac-scale/jac_scale/tests/fixtures/k8s_e2e";

        # 3. Embedded fallback when no user file + no shipped Dockerfile.
        proj3 = Path(tmp) / "myapp";
        proj3.mkdir();
        with mock.patch.object(ib_mod, "find_shipped_dockerfile", return_value=None) {
            (df, ctx, args) = resolve_dockerfile(proj3);
        }
        assert df.parent.name == ".jac";
        assert df.name == "Dockerfile.gen";
        contents = df.read_text();
        assert "FROM python:3.12-slim" in contents;
        assert "jac-scale[deploy,data]" in contents;
        assert "jac install" in contents;
    }
}


test "ensure_dockerignore writes embedded template + preserves FE dist; never overwrites" {
    with tempfile.TemporaryDirectory() as tmp {
        ctx = Path(tmp);
        assert ensure_dockerignore(ctx) is True;
        di = ctx / ".dockerignore";
        contents = di.read_text();
        # Caches dropped, FE bundle kept.
        assert "**/.jac/cache" in contents;
        assert "**/.jac/data" in contents;
        assert "**/node_modules" in contents;
        # FE bundle must NOT be ignored.
        assert "**/.jac/client/dist" not in contents;

        # Never overwrites a user-provided file.
        di.write_text("custom\n");
        assert ensure_dockerignore(ctx) is False;
        assert di.read_text() == "custom\n";
    }
}


test "build_client_bundle no-ops when client_entry is empty" {
    # Should return without touching subprocess at all.
    build_client_bundle(Path("/tmp"), "");
}


test "build_client_bundle invokes `jac build <entry>` from project_dir + verifies dist" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        dist = project / ".jac" / "client" / "dist";
        dist.mkdir(parents=True);
        (dist / "index.html").write_text("<html></html>");

        run_result = mock.MagicMock();
        run_result.returncode = 0;
        run_result.stdout = "";
        run_result.stderr = "";

        with mock.patch("shutil.which", return_value="/usr/bin/jac") {
            with mock.patch.object(ib_mod, "_jac_client_installed", return_value=True) {
                with mock.patch("subprocess.run", return_value=run_result) as run_mock {
                    build_client_bundle(project, "main.jac");
                    args = run_mock.call_args;
                    assert args.args[0] == ["jac", "build", "main.jac"];
                    assert args.kwargs["cwd"] == str(project);
                }
            }
        }
    }
}


test "build_client_bundle raises actionable error when post-build dist is missing" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        run_result = mock.MagicMock();
        run_result.returncode = 0;
        run_result.stdout = "";
        run_result.stderr = "";

        with mock.patch("shutil.which", return_value="/usr/bin/jac") {
            with mock.patch.object(ib_mod, "_jac_client_installed", return_value=True) {
                with mock.patch("subprocess.run", return_value=run_result) {
                    raised = False;
                    try {
                        build_client_bundle(project, "main.jac");
                    } except RuntimeError as e {
                        raised = True;
                        assert "no bundle" in str(e).lower() or "index.html" in str(e);
                    }
                    assert raised;
                }
            }
        }
    }
}


test "auto_build_and_distribute on minikube builds with docker-env override" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        (project / "main.jac").write_text("");
        env_overrides = {"DOCKER_HOST": "tcp://192.168.49.2:2376"};

        with mock.patch.object(ib_mod, "detect_cluster_type", return_value=CLUSTER_MINIKUBE):
            with mock.patch.object(ib_mod, "get_minikube_docker_env", return_value=env_overrides):
                with mock.patch.object(ib_mod, "_read_client_entry", return_value=""):
                    with mock.patch.object(ib_mod, "resolve_dockerfile",
                                          return_value=(Path("/Dockerfile.microservice"), project, {})):
                        with mock.patch.object(ib_mod, "run_docker_build") as build_mock:
                            with mock.patch.object(ib_mod, "_retag_with_content_id",
                                                   side_effect=lambda tag, env=None: f"{tag}-abc123"):
                                tag = auto_build_and_distribute("myapp", project);
                                assert tag == "myapp:dev-abc123";
                                assert build_mock.call_args.args[1] == "myapp:dev";
                                # docker-env was passed through.
                                assert build_mock.call_args.args[4] == env_overrides;
    }
}


test "auto_build_and_distribute on remote requires registry_url, pushes when given" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);

        # Missing registry_url -> actionable error.
        with mock.patch.object(ib_mod, "detect_cluster_type", return_value=CLUSTER_REMOTE):
            with mock.patch.object(ib_mod, "_read_client_entry", return_value=""):
                raised = False;
                try {
                    auto_build_and_distribute("myapp", project, registry_url=None);
                } except RuntimeError as e {
                    raised = True;
                    assert "registry" in str(e).lower();
                }
                assert raised;

        # With registry_url -> tags + pushes.
        with mock.patch.object(ib_mod, "detect_cluster_type", return_value=CLUSTER_REMOTE):
            with mock.patch.object(ib_mod, "_read_client_entry", return_value=""):
                with mock.patch.object(ib_mod, "resolve_dockerfile",
                                       return_value=(Path("/Dockerfile.microservice"), project, {})):
                    with mock.patch.object(ib_mod, "run_docker_build"):
                        with mock.patch.object(ib_mod, "_retag_with_content_id",
                                               side_effect=lambda tag, env=None: f"{tag}-abc123"):
                            with mock.patch.object(ib_mod, "run_docker_push") as push_mock:
                                tag = auto_build_and_distribute(
                                    "myapp", project, registry_url="reg.example.com/org"
                                );
                                assert tag == "reg.example.com/org/myapp:dev-abc123";
                                assert push_mock.call_args.args[0] == "reg.example.com/org/myapp:dev-abc123";
    }
}


test "auto_build_and_distribute on unknown cluster raises actionable error" {
    with mock.patch.object(ib_mod, "detect_cluster_type", return_value=CLUSTER_UNKNOWN):
        raised = False;
        try {
            auto_build_and_distribute("myapp", Path("/tmp"));
        } except RuntimeError as e {
            raised = True;
            assert "cluster" in str(e).lower();
        }
        assert raised;
}

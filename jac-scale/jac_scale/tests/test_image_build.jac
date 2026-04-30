"""Unit tests for the auto-build / auto-distribute pipeline (P0.5)."""

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


# =============================================================================
# find_jaseci_repo_root
# =============================================================================
test "find_jaseci_repo_root identifies a repo with both jac/ and jac-scale/" {
    with tempfile.TemporaryDirectory() as tmp {
        repo = Path(tmp) / "jaseci";
        (repo / "jac").mkdir(parents=True);
        (repo / "jac-scale").mkdir(parents=True);
        nested = repo / "examples" / "myproject";
        nested.mkdir(parents=True);
        result = find_jaseci_repo_root(nested);
        assert result is not None;
        assert result.resolve() == repo.resolve();
    }
}


test "find_jaseci_repo_root returns None when not in a jaseci checkout" {
    with tempfile.TemporaryDirectory() as tmp {
        target = Path(tmp) / "some" / "random" / "dir";
        target.mkdir(parents=True);
        result = find_jaseci_repo_root(target, max_levels=4);
        assert result is None;
    }
}


# =============================================================================
# resolve_dockerfile decision logic
# =============================================================================
test "resolve_dockerfile prefers user's Dockerfile.microservice when present" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        user_df = project / "Dockerfile.microservice";
        user_df.write_text("FROM scratch\n");
        (df, ctx, args) = resolve_dockerfile(project);
        assert df.resolve() == user_df.resolve();
        assert ctx.resolve() == project.resolve();
        assert args == {};
    }
}


test "resolve_dockerfile picks Dockerfile.microservice.ci for developer checkouts" {
    with tempfile.TemporaryDirectory() as tmp {
        repo = Path(tmp) / "jaseci";
        (repo / "jac").mkdir(parents=True);
        scripts_dir = repo / "jac-scale" / "scripts";
        scripts_dir.mkdir(parents=True);
        ci_df = scripts_dir / "Dockerfile.microservice.ci";
        ci_df.write_text("FROM python:3.12-slim\n# ci\n");
        project = repo / "jac-scale" / "jac_scale" / "tests" / "fixtures" / "k8s_e2e";
        project.mkdir(parents=True);
        (df, ctx, args) = resolve_dockerfile(project);
        assert df.resolve() == ci_df.resolve();
        assert ctx.resolve() == repo.resolve();
        assert "PROJECT_PATH" in args;
        assert args["PROJECT_PATH"] == "jac-scale/jac_scale/tests/fixtures/k8s_e2e";
    }
}


test "resolve_dockerfile falls back to embedded template + .jac/Dockerfile.gen" {
    # Mock find_shipped_dockerfile so the test isn't sensitive to whether
    # the running jac-scale install happens to have scripts/ shipped
    # alongside it (which it does in a developer checkout).
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp) / "myapp";
        project.mkdir();
        with mock.patch.object(ib_mod, "find_shipped_dockerfile", return_value=None) {
            (df, ctx, args) = resolve_dockerfile(project);
        }
        assert df.parent.name == ".jac";
        assert df.name == "Dockerfile.gen";
        assert df.exists();
        contents = df.read_text();
        assert "FROM python:3.12-slim" in contents;
        assert "jac-scale[deploy]" in contents;
        assert ctx.resolve() == project.resolve();
        assert args == {};
    }
}


test "resolve_dockerfile prefers shipped Dockerfile.microservice over embedded" {
    # When the jac-scale install ships a Dockerfile.microservice next to it
    # (the PyPI / sdist case), use that instead of generating the embedded
    # template. Caller's project_dir stays the build context.
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp) / "myapp";
        project.mkdir();
        fake_shipped = Path(tmp) / "fake_shipped_Dockerfile";
        fake_shipped.write_text("FROM python:3.12-slim\n# shipped\n");
        with mock.patch.object(
            ib_mod, "find_shipped_dockerfile", return_value=fake_shipped
        ) {
            (df, ctx, args) = resolve_dockerfile(project);
        }
        assert df.resolve() == fake_shipped.resolve();
        assert ctx.resolve() == project.resolve();
        assert args == {};
    }
}


# =============================================================================
# ensure_dockerignore - prevents 2GB build contexts from timing out
# =============================================================================
test "ensure_dockerignore writes the embedded template when absent" {
    with tempfile.TemporaryDirectory() as tmp {
        ctx = Path(tmp);
        wrote = ensure_dockerignore(ctx);
        assert wrote;
        ignore_file = ctx / ".dockerignore";
        assert ignore_file.exists();
        contents = ignore_file.read_text();
        # Must exclude the things that bloat builds the most.
        assert ".git" in contents;
        assert "**/.jac/cache" in contents;
        assert "**/__pycache__" in contents;
        assert "**/node_modules" in contents;
    }
}


test "embedded dockerignore preserves .jac/client/dist for FE serving" {
    # Regression: P0.7 builds the FE into .jac/client/dist BEFORE the
    # docker build. If the dockerignore had a blanket `**/.jac` rule
    # (the original P0.5 shape), the FE bundle would silently be
    # filtered out of the build context and the gateway pod would have
    # nothing to serve at /. The embedded template must exclude
    # specific .jac subdirs only - not .jac/client/.
    with tempfile.TemporaryDirectory() as tmp {
        ctx = Path(tmp);
        ensure_dockerignore(ctx);
        contents = (ctx / ".dockerignore").read_text();
        # Specific subdirs excluded
        assert "**/.jac/cache" in contents;
        assert "**/.jac/data" in contents;
        # Blanket exclusion absent (would block the FE bundle)
        assert "**/.jac\n" not in contents;
        # And the bare path "**/.jac" as a standalone rule (without trailing
        # subdir) must not appear; specific subdirs are fine.
        for line in contents.splitlines() {
            stripped = line.strip();
            assert stripped != "**/.jac" , (
                "blanket **/.jac rule would exclude .jac/client/dist"
            );
            assert stripped != ".jac" , "same blanket rule under different shape";
        }
    }
}


test "P0.7: build_client_bundle no-ops when client_entry is empty" {
    # Apps without a frontend (LLM-only / API-only) shouldn't trigger
    # any subprocess work just because the auto-build runs.
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        # subprocess.run shouldn't be called at all - if it were called
        # we'd see the mock recording. Use a fresh patch and assert
        # call_count == 0.
        with mock.patch("subprocess.run") as mock_run {
            build_client_bundle(project, "");
            assert mock_run.call_count == 0;
        }
    }
}


test "P0.7: build_client_bundle invokes `jac build <entry>` from project_dir" {
    # The orchestrator runs `jac build` for the local-mode FE bundle;
    # the K-track auto-build needs to do the same on the host BEFORE
    # docker build, so .jac/client/dist/ exists when the project gets
    # COPY'd into the image. We mock shutil.which so the test isn't
    # sensitive to whether the jac binary is on the test runner's PATH.
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        fake_result = mock.MagicMock(returncode=0, stdout="", stderr="");
        with mock.patch("shutil.which", return_value="/usr/local/bin/jac") {
            with mock.patch("subprocess.run", return_value=fake_result) as mock_run {
                build_client_bundle(project, "main.jac");
                assert mock_run.call_count == 1;
                (args, kwargs) = mock_run.call_args;
                cmd = args[0];
                assert cmd == ["jac", "build", "main.jac"];
                # cwd must be project_dir so jac sees the right jac.toml
                assert kwargs["cwd"] == str(project);
            }
        }
    }
}


test "P0.7: build_client_bundle raises actionable error on non-zero exit" {
    # User edits a frontend .jac file that has a syntax error - we
    # surface it as a RuntimeError naming the entry + last 20 lines
    # of jac build output so they don't have to hunt through hundreds
    # of vite warnings.
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        fake_result = mock.MagicMock(
            returncode=1,
            stdout="building dist/...\n",
            stderr="error: unexpected token at line 42\n"
        );
        with mock.patch("shutil.which", return_value="/usr/local/bin/jac") {
            with mock.patch("subprocess.run", return_value=fake_result) {
                raised = False;
                msg = "";
                try {
                    build_client_bundle(project, "broken.jac");
                } except RuntimeError as e {
                    raised = True;
                    msg = str(e);
                }
                assert raised;
                assert "broken.jac" in msg;
                assert "exit 1" in msg;
                assert "unexpected token" in msg;
            }
        }
    }
}


test "ensure_dockerignore never overwrites a user-provided .dockerignore" {
    with tempfile.TemporaryDirectory() as tmp {
        ctx = Path(tmp);
        existing = ctx / ".dockerignore";
        existing.write_text("# user's custom rules\nuser-only-marker\n");
        wrote = ensure_dockerignore(ctx);
        assert not wrote;
        # Must NOT have been clobbered.
        contents = existing.read_text();
        assert "user-only-marker" in contents;
        assert "**/.jac" not in contents;  # our embedded marker
    }
}


# =============================================================================
# auto_build_and_distribute - dispatch on cluster type
# =============================================================================
test "auto_build_and_distribute on minikube uses docker-env override" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        (project / "Dockerfile.microservice").write_text("FROM scratch\n");
        called: dict[str, Any] = {};
        def fake_build(
            context_dir: Any,
            image_tag: str,
            dockerfile: Any,
            build_args: dict,
            env_overrides: Any = None
        ) {
            called["image_tag"] = image_tag;
            called["env_overrides"] = env_overrides;
        }
        with mock.patch.object(
            ib_mod, "detect_cluster_type", return_value=CLUSTER_MINIKUBE
        ) {
            with mock.patch.object(
                ib_mod,
                "get_minikube_docker_env",
                return_value={"DOCKER_HOST": "tcp://192.168.49.2:2376"}
            ) {
                with mock.patch.object(
                    ib_mod, "run_docker_build", side_effect=fake_build
                ) {
                    tag = auto_build_and_distribute("myapp", project);
                }
            }
        }
        assert tag == "myapp:dev";
        assert called["image_tag"] == "myapp:dev";
        assert called["env_overrides"]["DOCKER_HOST"] == "tcp://192.168.49.2:2376";
    }
}


test "auto_build_and_distribute on k3d builds + imports into cluster" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        (project / "Dockerfile.microservice").write_text("FROM scratch\n");
        import_called: dict[str, Any] = {};
        def fake_import(image_tag: str, cluster: str) {
            import_called["image_tag"] = image_tag;
            import_called["cluster"] = cluster;
        }
        with mock.patch.object(
            ib_mod, "detect_cluster_type", return_value=CLUSTER_K3D
        ) {
            with mock.patch.object(
                ib_mod, "_active_context_name", return_value="k3d-mycluster"
            ) {
                with mock.patch.object(ib_mod, "run_docker_build") {
                    with mock.patch.object(
                        ib_mod, "run_k3d_image_import", side_effect=fake_import
                    ) {
                        tag = auto_build_and_distribute("myapp", project);
                    }
                }
            }
        }
        assert tag == "myapp:dev";
        assert import_called["cluster"] == "mycluster";
    }
}


test "auto_build_and_distribute on kind builds + loads into cluster" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        (project / "Dockerfile.microservice").write_text("FROM scratch\n");
        load_called: dict[str, Any] = {};
        def fake_load(image_tag: str, cluster: str) {
            load_called["cluster"] = cluster;
        }
        with mock.patch.object(
            ib_mod, "detect_cluster_type", return_value=CLUSTER_KIND
        ) {
            with mock.patch.object(
                ib_mod, "_active_context_name", return_value="kind-test"
            ) {
                with mock.patch.object(ib_mod, "run_docker_build") {
                    with mock.patch.object(
                        ib_mod, "run_kind_image_load", side_effect=fake_load
                    ) {
                        tag = auto_build_and_distribute("myapp", project);
                    }
                }
            }
        }
        assert load_called["cluster"] == "test";
    }
}


test "auto_build_and_distribute on remote requires registry_url" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        (project / "Dockerfile.microservice").write_text("FROM scratch\n");
        with mock.patch.object(
            ib_mod, "detect_cluster_type", return_value=CLUSTER_REMOTE
        ) {
            raised = False;
            msg = "";
            try {
                auto_build_and_distribute("myapp", project, registry_url=None);
            } except RuntimeError as e {
                raised = True;
                msg = str(e);
            }
            assert raised;
            assert "registry" in msg.lower();
            assert "image_registry" in msg;
        }
    }
}


test "auto_build_and_distribute on remote tags + pushes when registry given" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        (project / "Dockerfile.microservice").write_text("FROM scratch\n");
        push_called: dict[str, Any] = {};
        def fake_push(image_tag: str) {
            push_called["image_tag"] = image_tag;
        }
        with mock.patch.object(
            ib_mod, "detect_cluster_type", return_value=CLUSTER_REMOTE
        ) {
            with mock.patch.object(ib_mod, "run_docker_build") {
                with mock.patch.object(
                    ib_mod, "run_docker_push", side_effect=fake_push
                ) {
                    tag = auto_build_and_distribute(
                        "myapp", project, registry_url="ghcr.io/myorg"
                    );
                }
            }
        }
        assert tag == "ghcr.io/myorg/myapp:dev";
        assert push_called["image_tag"] == "ghcr.io/myorg/myapp:dev";
    }
}


test "auto_build_and_distribute on unknown cluster raises actionable error" {
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        with mock.patch.object(
            ib_mod, "detect_cluster_type", return_value=CLUSTER_UNKNOWN
        ) {
            raised = False;
            msg = "";
            try {
                auto_build_and_distribute("myapp", project);
            } except RuntimeError as e {
                raised = True;
                msg = str(e);
            }
            assert raised;
            assert "kubeconfig" in msg.lower() or "cluster" in msg.lower();
            assert "minikube start" in msg or "kubectl cluster-info" in msg;
        }
    }
}

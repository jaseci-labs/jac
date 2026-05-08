"""Unit tests for the auto-build / auto-distribute pipeline."""

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
        # Embedded template installs the [deploy,data] extras so pymongo
        # + redis are available in the runtime image for Mongo/Redis
        # auto-provisioning.
        assert "jac-scale[deploy,data]" in contents;
        # jac-client must be installed so the `jac install` step
        # below can resolve jac.toml [dependencies].
        assert "jac-client" in contents;
        # must run `jac install` so user app deps land in the image.
        assert "jac install" in contents;
        assert ctx.resolve() == project.resolve();
        assert args == {};
    }
}


# =============================================================================
# shipped + dev-checkout Dockerfiles also install user pip deps
# =============================================================================
test "Shipped Dockerfile.microservice installs jac-client + runs jac install" {
    # Apps that auto-build via the shipped (PyPI-install) variant must
    # also get their jac.toml [dependencies] resolved. Without this,
    # any real app that declares pip deps (jacBuilder declares
    # websockets/httpx/watchdog/mcp) would crash at startup with a
    # `ModuleNotFoundError`.
    shipped = ib_mod.find_shipped_dockerfile();
    if shipped is None {
        # Test runner doesn't have a shipped variant on disk (rare; happens
        # for non-editable installs without scripts/). Skip rather than
        # asserting against a None.
        return;
    }
    contents = shipped.read_text();
    assert "jac-client" in contents , (
        "shipped Dockerfile.microservice missing jac-client install"
    );
    assert "jac install" in contents , (
        "shipped Dockerfile.microservice missing `jac install` step"
    );
}


test "Dev-checkout Dockerfile.microservice.ci installs jac-client + runs jac install" {
    # The CI variant (used when project_dir is inside a jaseci checkout)
    # has the same requirement - users on dev checkouts get the same
    # auto-installed deps as users on a PyPI install.
    with tempfile.TemporaryDirectory() as tmp {
        repo = Path(tmp) / "jaseci";
        (repo / "jac").mkdir(parents=True);
        scripts_dir = repo / "jac-scale" / "scripts";
        scripts_dir.mkdir(parents=True);
        # Mirror the contents we expect on a real checkout. find_jaseci_repo_root
        # walks based on directory existence, not file content, so a stub file
        # is enough to satisfy resolve_dockerfile's decision tree.
        ci_df = scripts_dir / "Dockerfile.microservice.ci";
        # Use the actual file from the repo so the assertion catches
        # drift (someone removing `jac install` from the CI Dockerfile).
        import shutil as _shutil;
        real_ci = (
            Path(ib_mod.__file__).parent.parent.parent / "scripts" / "Dockerfile.microservice.ci"
        );
        if not real_ci.is_file() {
            return;
        }
        _shutil.copy(real_ci, ci_df);
        contents = ci_df.read_text();
        assert "jac-client" in contents , (
            "Dockerfile.microservice.ci missing jac-client install"
        );
        assert "jac install" in contents , (
            "Dockerfile.microservice.ci missing `jac install` step"
        );
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
    # Regression: the FE bundle is built into .jac/client/dist BEFORE
    # the docker build. If the dockerignore had a blanket `**/.jac`
    # rule, the FE bundle would silently be filtered out of the build
    # context and the gateway pod would have nothing to serve at /.
    # The embedded template must exclude specific .jac subdirs only -
    # not .jac/client/.
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


test "Build_client_bundle no-ops when client_entry is empty" {
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


test "Build_client_bundle invokes `jac build <entry>` from project_dir" {
    # The orchestrator runs `jac build` for the local-mode FE bundle;
    # theauto-build needs to do the same on the host BEFORE
    # docker build, so .jac/client/dist/ exists when the project gets
    # COPY'd into the image. We mock shutil.which so the test isn't
    # sensitive to whether the jac binary is on the test runner's PATH.
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        # Pre-create the dist artifact so the post-build assertion is
        # satisfied - this test is about the subprocess call shape, not
        # the artifact check.
        dist = project / ".jac" / "client" / "dist";
        dist.mkdir(parents=True);
        (dist / "index.html").write_text("<html></html>");
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


test "Build_client_bundle raises actionable error on non-zero exit" {
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


# =============================================================================
# jac-client pre-flight check
# =============================================================================
test "Build_client_bundle raises if jac-client not importable" {
    # Without this guard, missing jac-client manifests as a silent FE-skip:
    # `jac build` returns exit 0 (or unhelpful stderr) and the docker image
    # ships without .jac/client/dist/. The user sees a blank gateway page
    # and has no breadcrumb leading back to the missing pip install.
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        with mock.patch("shutil.which", return_value="/usr/local/bin/jac") {
            with mock.patch.object(
                ib_mod, "_jac_client_installed", return_value=False
            ) {
                raised = False;
                msg = "";
                try {
                    build_client_bundle(project, "main.jac");
                } except RuntimeError as e {
                    raised = True;
                    msg = str(e);
                }
                assert raised;
                # Must name the package + the fix the user can act on.
                assert "jac-client" in msg;
                assert "pip install jac-client" in msg;
                # Must echo the entry the user configured.
                assert "main.jac" in msg;
            }
        }
    }
}


test "Build_client_bundle proceeds when jac-client present" {
    # Companion to the missing-jac-client test - confirms the guard
    # doesn't fire false-positives when the package IS installed.
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        # Pre-create the dist file so the post-build assertion passes.
        dist = project / ".jac" / "client" / "dist";
        dist.mkdir(parents=True);
        (dist / "index.html").write_text("<html></html>");
        run_calls: dict[str, int] = {"count": 0};
        def fake_run(*_args: Any, **_kwargs: Any) -> Any {
            run_calls["count"] += 1;
            return mock.MagicMock(returncode=0, stdout="", stderr="");
        }
        with mock.patch("shutil.which", return_value="/usr/local/bin/jac") {
            with mock.patch.object(
                ib_mod, "_jac_client_installed", return_value=True
            ) {
                with mock.patch("subprocess.run", side_effect=fake_run) {
                    build_client_bundle(project, "main.jac");
                }
            }
        }
        # The actual jac build subprocess should still run.
        assert run_calls["count"] == 1;
    }
}


# =============================================================================
# post-build dist assertion
# =============================================================================
test "Build_client_bundle raises when index.html absent post-build" {
    # `jac build` can return exit 0 without producing dist/index.html
    # (cached-but-broken state, vite skip on missing entry). Without
    # this assertion the docker COPY step succeeds and the gateway pod
    # silently serves nothing - looks like the platform is broken when
    # the cause is one config away.
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        # Notably DO NOT create .jac/client/dist/index.html
        fake_result = mock.MagicMock(returncode=0, stdout="", stderr="");
        with mock.patch("shutil.which", return_value="/usr/local/bin/jac") {
            with mock.patch.object(
                ib_mod, "_jac_client_installed", return_value=True
            ) {
                with mock.patch("subprocess.run", return_value=fake_result) {
                    raised = False;
                    msg = "";
                    try {
                        build_client_bundle(project, "main.jac");
                    } except RuntimeError as e {
                        raised = True;
                        msg = str(e);
                    }
                    assert raised;
                    # Error must point at the missing artifact + name the
                    # entry so users can reproduce manually.
                    assert "index.html" in msg;
                    assert "main.jac" in msg;
                    assert "no FE bundle" in msg or "no FE" in msg;
                }
            }
        }
    }
}


test "Build_client_bundle accepts dist created by jac build" {
    # If jac build does its job, no exception. Companion to the
    # absent-bundle test.
    with tempfile.TemporaryDirectory() as tmp {
        project = Path(tmp);
        dist = project / ".jac" / "client" / "dist";
        dist.mkdir(parents=True);
        (dist / "index.html").write_text("<html></html>");
        fake_result = mock.MagicMock(returncode=0, stdout="", stderr="");
        with mock.patch("shutil.which", return_value="/usr/local/bin/jac") {
            with mock.patch.object(
                ib_mod, "_jac_client_installed", return_value=True
            ) {
                with mock.patch("subprocess.run", return_value=fake_result) {
                    # No exception expected.
                    build_client_bundle(project, "main.jac");
                }
            }
        }
    }
}


# =============================================================================
# content-addressed image tag (force rollout on content change)
# =============================================================================
test "_docker_image_id returns sha256:<hex> when inspect succeeds" {
    fake_result = mock.MagicMock(
        returncode=0, stdout="sha256:abcdef0123456789aaaa\n", stderr=""
    );
    with mock.patch("subprocess.run", return_value=fake_result) {
        digest = ib_mod._docker_image_id("myapp:dev");
    }
    assert digest == "sha256:abcdef0123456789aaaa";
}


test "_docker_image_id returns None on inspect failure" {
    # docker not installed, image absent, daemon unreachable - all
    # collapse to None so the caller can fall back to the base tag.
    fake_result = mock.MagicMock(returncode=1, stdout="", stderr="No such image");
    with mock.patch("subprocess.run", return_value=fake_result) {
        digest = ib_mod._docker_image_id("not-real:dev");
    }
    assert digest is None;
}


test "_docker_image_id passes env_overrides through to subprocess" {
    # Minikube case: docker daemon lives inside the VM; the inspect call
    # needs DOCKER_HOST/CERT_PATH overrides or it'd query the wrong
    # daemon and return None for an image that exists where it matters.
    captured: dict[str, Any] = {};
    def fake_run(*_args: Any, **kwargs: Any) -> Any {
        captured["env"] = kwargs.get("env");
        return mock.MagicMock(
            returncode=0, stdout="sha256:cafe1234567890ab\n", stderr=""
        );
    }
    with mock.patch("subprocess.run", side_effect=fake_run) {
        digest = ib_mod._docker_image_id(
            "myapp:dev", env_overrides={"DOCKER_HOST": "tcp://192.168.49.2:2376"}
        );
    }
    assert digest == "sha256:cafe1234567890ab";
    assert captured["env"]["DOCKER_HOST"] == "tcp://192.168.49.2:2376";
}


test "_retag_with_content_id appends 12-char id to base tag" {
    full_id = "sha256:abcdef012345dead0000beef0000face1234";
    expected_short = "abcdef012345";  # first 12 hex chars after sha256:
    fake_tag_ok = mock.MagicMock(returncode=0, stdout="", stderr="");
    with mock.patch.object(ib_mod, "_docker_image_id", return_value=full_id) {
        with mock.patch("subprocess.run", return_value=fake_tag_ok) {
            new_tag = ib_mod._retag_with_content_id("myapp:dev");
        }
    }
    assert new_tag == f"myapp:dev-{expected_short}";
}


test "_retag_with_content_id preserves registry prefix" {
    # Remote-cluster tags include the registry prefix; the new tag must
    # too, otherwise the push would target the wrong repo.
    full_id = "sha256:0011223344556677889900";
    fake_tag_ok = mock.MagicMock(returncode=0, stdout="", stderr="");
    with mock.patch.object(ib_mod, "_docker_image_id", return_value=full_id) {
        with mock.patch("subprocess.run", return_value=fake_tag_ok) {
            new_tag = ib_mod._retag_with_content_id("ghcr.io/org/myapp:dev");
        }
    }
    assert new_tag == "ghcr.io/org/myapp:dev-001122334455";
}


test "_retag_with_content_id falls back to base_tag when inspect fails" {
    # If docker inspect can't read the digest (daemon down, image
    # missing, etc.), keep the deploy moving with the bare :dev tag.
    # Manual `kubectl rollout restart` is the workaround; better than
    # crashing the whole `jac start --scale`.
    with mock.patch.object(ib_mod, "_docker_image_id", return_value=None) {
        new_tag = ib_mod._retag_with_content_id("myapp:dev");
    }
    assert new_tag == "myapp:dev";
}


test "_retag_with_content_id falls back when docker tag fails" {
    # docker inspect succeeded so we know the digest - but the docker
    # tag step itself failed (rare; would mean daemon hiccupped between
    # two calls). Same fallback: let the deploy continue with the base
    # tag rather than half-committed state.
    fake_tag_fail = mock.MagicMock(returncode=1, stdout="", stderr="failed to tag");
    with mock.patch.object(
        ib_mod, "_docker_image_id", return_value="sha256:abc123def4567890aaaa"
    ) {
        with mock.patch("subprocess.run", return_value=fake_tag_fail) {
            new_tag = ib_mod._retag_with_content_id("myapp:dev");
        }
    }
    assert new_tag == "myapp:dev";
}


test "Auto_build_and_distribute on k3d imports the retagged image" {
    # End-to-end check on the K3D path: the tag flowing into
    # k3d image import (and therefore into the manifest) must be the
    # content-addressed one, not the bare `:dev`.
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
                        ib_mod,
                        "_retag_with_content_id",
                        return_value="myapp:dev-cafe12345678"
                    ) {
                        with mock.patch.object(
                            ib_mod, "run_k3d_image_import", side_effect=fake_import
                        ) {
                            tag = auto_build_and_distribute("myapp", project);
                        }
                    }
                }
            }
        }
        assert tag == "myapp:dev-cafe12345678";
        assert import_called["image_tag"] == "myapp:dev-cafe12345678";
    }
}


test "Auto_build_and_distribute on remote pushes the retagged image" {
    # Equivalent check on the registry path - what gets pushed (and
    # what the manifest references on the remote cluster) must be
    # the content-addressed tag.
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
                    ib_mod,
                    "_retag_with_content_id",
                    return_value="ghcr.io/myorg/myapp:dev-deadbeef0011"
                ) {
                    with mock.patch.object(
                        ib_mod, "run_docker_push", side_effect=fake_push
                    ) {
                        tag = auto_build_and_distribute(
                            "myapp", project, registry_url="ghcr.io/myorg"
                        );
                    }
                }
            }
        }
        assert tag == "ghcr.io/myorg/myapp:dev-deadbeef0011";
        assert push_called["image_tag"] == "ghcr.io/myorg/myapp:dev-deadbeef0011";
    }
}

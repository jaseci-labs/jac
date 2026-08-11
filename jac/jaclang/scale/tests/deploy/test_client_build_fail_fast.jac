"""A deploy's client bundle is built once, on the host, and shipped to the
gateway pod. A failed build must fail the deploy right there, with the real
build error - not ship a broken bundle and leave the gateway pod to retry the
build at boot, where the failure surfaces minutes later as crash-loop noise
that reads like a client-build problem regardless of the real cause.

These drive the real ManifestBuilder against real project folders (the broken
build runs the actual `jac build` subprocess); no mocks."""

import os;
import shutil;
import subprocess;
import tempfile;
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.runtime.context.util { jac_executable }


def _builder(project_dir: str) -> ManifestBuilder {
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="landing", namespace="jb-landing"),
        microservices_config={"client": {"entry": "main.jac"}}
    );
    mb.project_dir = project_dir;
    return mb;
}


def _project(entry_source: str) -> str {
    tmp = tempfile.mkdtemp(prefix="client-fail-fast-");
    with open(os.path.join(tmp, "jac.toml"), "w", encoding="utf-8") as f {
        f.write('[project]\nname = "landing"\nentry-point = "main.jac"\n');
    }
    with open(os.path.join(tmp, "main.jac"), "w", encoding="utf-8") as f {
        f.write(entry_source);
    }
    return tmp;
}


"""A counting `jac` stand-in: fails with a canned install-failure message for
the first `fail_first` build invocations, then hands off to the real binary.
Every other subcommand (the dependency install that precedes the build) passes
straight through, so the counter tracks build attempts alone. Uses the
codebase's own JAC_EXECUTABLE substitution seam, not a mock."""
def _counting_jac(tmp: str, fail_first: int, failure_text: str) -> tuple {
    counter = os.path.join(tmp, "attempts");
    real_jac = jac_executable();
    script = os.path.join(tmp, "counting-jac.sh");
    with open(script, "w", encoding="utf-8") as f {
        f.write(
            "#!/bin/sh\n"
                + f'if [ "$1" != "build" ]; then exec "{real_jac}" "$@"; fi\n'
                + f'count_file="{counter}"\n'
                + 'n=$(cat "$count_file" 2>/dev/null || echo 0)\n'
                + "n=$((n+1))\n"
                + 'printf %s "$n" > "$count_file"\n'
                + f'if [ "$n" -le {fail_first} ]; then\n'
                + f'  echo "{failure_text}" >&2\n'
                + "  exit 1\n"
                + "fi\n"
                + f'exec "{real_jac}" "$@"\n'
        );
    }
    os.chmod(script, 0o755);
    return (script, counter);
}


def _attempts(counter: str) -> int {
    if not os.path.isfile(counter) {
        return 0;
    }
    with open(counter, encoding="utf-8") as f {
        return int(f.read().strip() or "0");
    }
}


def _web_app_project(tmp: str) -> str {
    created = subprocess.run(
        [jac_executable(), "create", "app", "--kind", "web-app"],
        cwd=tmp,
        capture_output=True,
        text=True,
        timeout=300
    );
    assert created.returncode == 0 , (
        f"jac create failed: {created.stdout}\n{created.stderr}"
    );
    return os.path.join(tmp, "app");
}


test "a failing client build aborts the deploy with the build error" {
    project_dir = _project("with entry { this does not parse ((( }\n");
    raised = None;
    try {
        _builder(project_dir)._build_client_bundle(project_dir);
    } except Exception as e {
        raised = e;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert raised is not None , (
        "a failed client build must abort the deploy, not fall through to a "
        "pod-boot rebuild"
    );
    assert "client" in str(raised).lower() , f"error names no cause: {raised}";
}


test "the gateway pod command carries no client rebuild fallback" {
    project_dir = _project("with entry {}\n");
    try {
        entrypoint = _builder(project_dir)._pod_entrypoint();
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    args = "".join(entrypoint.get("args", []));
    assert "exec jac scale gateway" in args;
    assert "jac build" not in args , (
        f"the pod still rebuilds the client at boot: {args}"
    );
    assert "building client bundle" not in args;
}


test "an app without a client entry skips the build untouched" {
    project_dir = _project("with entry {}\n");
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="api", namespace="jb-api"),
        microservices_config={"client": {"entry": False}}
    );
    mb.project_dir = project_dir;
    try {
        mb._build_client_bundle(project_dir);
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }
}


test "a transient install failure is retried and the deploy succeeds" {
    tmp = tempfile.mkdtemp(prefix="client-retry-");
    saved = os.environ.get("JAC_EXECUTABLE");
    try {
        project_dir = _web_app_project(tmp);
        (script, counter) = _counting_jac(tmp, 1, "bun install failed after 12.0s");
        os.environ["JAC_EXECUTABLE"] = script;
        _builder(project_dir)._build_client_bundle(project_dir);

        assert _attempts(counter) == 2 , (
            f"expected a retry after the transient failure, "
            f"saw {_attempts(counter)} attempt(s)"
        );
        index_html = os.path.join(project_dir, ".jac", "client", "dist", "index.html");
        assert os.path.isfile(index_html) , "retry did not produce a bundle";
    } finally {
        if saved is None {
            os.environ.pop("JAC_EXECUTABLE", None);
        } else {
            os.environ["JAC_EXECUTABLE"] = saved;
        }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a persistent transient failure still fails after a bounded retry" {
    tmp = tempfile.mkdtemp(prefix="client-retry-");
    saved = os.environ.get("JAC_EXECUTABLE");
    raised = None;
    try {
        project_dir = _project("with entry {}\n");
        (script, counter) = _counting_jac(
            tmp, 99, "Dependency installation failed after 30.0s"
        );
        os.environ["JAC_EXECUTABLE"] = script;
        try {
            _builder(project_dir)._build_client_bundle(project_dir);
        } except Exception as e {
            raised = e;
        }

        assert raised is not None , "an always-failing build must still fail";
        assert "client build failed" in str(raised);
        assert _attempts(counter) == 3 , (
            f"retry must be bounded at 3 attempts, saw {_attempts(counter)}"
        );
        shutil.rmtree(project_dir, ignore_errors=True);
    } finally {
        if saved is None {
            os.environ.pop("JAC_EXECUTABLE", None);
        } else {
            os.environ["JAC_EXECUTABLE"] = saved;
        }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a genuine compile error fails on the first attempt with no retry" {
    tmp = tempfile.mkdtemp(prefix="client-retry-");
    saved = os.environ.get("JAC_EXECUTABLE");
    raised = None;
    try {
        project_dir = _project("with entry { this does not parse ((( }\n");
        (script, counter) = _counting_jac(tmp, 0, "");
        os.environ["JAC_EXECUTABLE"] = script;
        try {
            _builder(project_dir)._build_client_bundle(project_dir);
        } except Exception as e {
            raised = e;
        }

        assert raised is not None , "a compile error must fail the deploy";
        assert _attempts(counter) == 1 , (
            f"a compile error must not be retried, saw {_attempts(counter)} "
            f"attempt(s)"
        );
        shutil.rmtree(project_dir, ignore_errors=True);
    } finally {
        if saved is None {
            os.environ.pop("JAC_EXECUTABLE", None);
        } else {
            os.environ["JAC_EXECUTABLE"] = saved;
        }
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

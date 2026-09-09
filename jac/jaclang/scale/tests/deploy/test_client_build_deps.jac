"""The client bundle is built on the deploy host, not in the pod, and that
build imports the app's whole module graph to find its client exports. So the
host needs the same Python packages the pod gets at boot: a client entry that
reaches any `[dependencies]`-backed module dies with `ModuleNotFoundError`
otherwise, and since the build is fatal that kills the whole deploy.

These drive the real ManifestBuilder against real project folders, running the
actual `jac install` and `jac build` subprocesses; no mocks. Where a test needs
to see inside the build's ephemeral stage, it goes through the codebase's own
JAC_EXECUTABLE seam with a wrapper that hands every call to the real binary."""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }
import from jaclang.scale.runtime.context.util { jac_executable }

# Tiny, pure-python, zero-dependency package: enough to prove the host build
# env is populated from [dependencies] without making this a download test.
glob APP_DEP: str = "toposort",
     MISSING_DEP: str = "jac-nonexistent-package-8010";


def _builder(project_dir: str, dry_run: bool = False) -> ManifestBuilder {
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="shop", namespace="jb-shop"),
        client_entry="main.jac",
        dry_run=dry_run
    );
    mb.project_dir = project_dir;
    return mb;
}


# A client app whose entry reaches a server module that imports a Python
# package, which is the shape every jac-client app has.
def _project(dependencies: str, server_import: str) -> str {
    tmp = tempfile.mkdtemp(prefix="client-build-deps-");
    files = {
        "jac.toml": (
            '[project]\nname = "shop"\nentry-point = "main.jac"\n\n'
            f"[dependencies]\n{dependencies}\n\n"
            '[dependencies.npm]\nreact = "^19.2.0"\nreact-dom = "^19.2.0"\n'
        ),
        "db.jac": (
            f"import {server_import};\n\n"
            "def probe() -> str {\n"
            f"    return str({server_import});\n"
            "}\n"
        ),
        "main.jac": (
            "import from db { probe }\n\n"
            "def:pub app() -> JsxElement {\n"
            "    return <div>shop</div>;\n"
            "}\n\n"
            "with entry {\n"
            "    print(probe());\n"
            "}\n"
        ),

    };
    for (name, source) in files.items() {
        with open(os.path.join(tmp, name), "w", encoding="utf-8") as f {
            f.write(source);
        }
    }
    return tmp;
}


"""A jac wrapper that runs the real binary and, once `install` has finished,
lists what it put into the build env's venv. The stage is gone by the time the
builder returns, so this is the only place the install's outcome is visible."""
def _venv_probing_jac(tmp: str, record: str) -> str {
    real_jac = jac_executable();
    script = os.path.join(tmp, "probing-jac.sh");
    with open(script, "w", encoding="utf-8") as f {
        f.write(
            "#!/bin/sh\n"
                + f'"{real_jac}" "$@"\n'
                + "rc=$?\n"
                + 'if [ "$1" = "install" ] && [ "$rc" = "0" ]; then\n'
                + f'  pwd > "{record}/install_cwd"\n'
                + f'  ls -d .jac/venv/lib/python*/site-packages/{APP_DEP}* '
                + f'> "{record}/installed" 2>/dev/null\n'
                + "fi\n"
                + 'exit "$rc"\n'
        );
    }
    os.chmod(script, 0o755);
    return script;
}


test "the host client build installs the app's declared dependencies" {
    project_dir = _project(f'{APP_DEP} = ">=1.10"', APP_DEP);
    record = tempfile.mkdtemp(prefix="client-build-deps-rec-");
    script = _venv_probing_jac(record, record);
    saved = os.environ.get("JAC_EXECUTABLE");
    os.environ["JAC_EXECUTABLE"] = script;
    raised = None;
    try {
        _builder(project_dir)._build_client_bundle(project_dir);
    } except Exception as e {
        raised = e;
    } finally {
        if saved is None {
            os.environ.pop("JAC_EXECUTABLE", None);
        } else {
            os.environ["JAC_EXECUTABLE"] = saved;
        }
        built = (
            Path(project_dir) / ".jac" / "client" / "dist" / "index.html"
        ).is_file();
        install_cwd = "";
        installed = "";
        if os.path.isfile(os.path.join(record, "install_cwd")) {
            with open(os.path.join(record, "install_cwd"), encoding="utf-8") as f {
                install_cwd = f.read().strip();
            }
        }
        if os.path.isfile(os.path.join(record, "installed")) {
            with open(os.path.join(record, "installed"), encoding="utf-8") as f {
                installed = f.read().strip();
            }
        }
        shutil.rmtree(project_dir, ignore_errors=True);
        shutil.rmtree(record, ignore_errors=True);
    }

    assert install_cwd , "the deploy never ran the dependency install";
    assert Path(install_cwd).resolve() != Path(project_dir).resolve() , (
        "the install ran on the raw project tree, not the build stage"
    );
    assert APP_DEP in installed , (
        "the deploy never installed the app's [dependencies] into the build "
        f"env, so any client entry reaching a {APP_DEP}-backed module cannot "
        f"build there (venv listing: {installed!r})"
    );
    assert raised is None , (
        f"the client build failed even though {APP_DEP} was installed: {raised}"
    );
    assert built , "the gateway would have nothing to serve";
}


test "a dependency the host cannot install does not abort the deploy" {
    # The build host is not the pod's platform, so a declared package can be
    # unresolvable here and install fine in the pod. That stays a warning:
    # only the build itself decides whether the deploy dies.
    project_dir = _project(f'{MISSING_DEP} = ">=1.0"', "json");
    raised = None;
    try {
        _builder(project_dir)._build_client_bundle(project_dir);
    } except Exception as e {
        raised = e;
    } finally {
        built = (
            Path(project_dir) / ".jac" / "client" / "dist" / "index.html"
        ).is_file();
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert raised is None , f"an unresolvable dep must not fail the deploy: {raised}";
    assert built;
}


test "a client build that dies on a missing import names the failed install" {
    project_dir = _project(f'{MISSING_DEP} = ">=1.0"', "jac_nonexistent_module_8010");
    raised = None;
    try {
        _builder(project_dir)._build_client_bundle(project_dir);
    } except Exception as e {
        raised = e;
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert raised is not None , "a broken client build must still fail the deploy";
    message = str(raised);
    assert "client build failed" in message;
    assert "dependencies did not install" in message , (
        "a build that died on a missing import must say the dependency "
        f"install failed first, not just dump the traceback: {message}"
    );
}


test "a dry run installs nothing and builds nothing" {
    project_dir = _project(f'{APP_DEP} = ">=1.10"', APP_DEP);
    try {
        _builder(project_dir, dry_run=True)._build_client_bundle(project_dir);
        touched = (Path(project_dir) / ".jac").exists();
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert not touched , "a dry run must not install or build anything";
}

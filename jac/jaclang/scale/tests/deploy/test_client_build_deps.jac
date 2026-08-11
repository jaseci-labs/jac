"""The client bundle is built on the deploy host, not in the pod, and that
build imports the app's whole module graph to find its client exports. So the
host needs the same Python packages the pod gets at boot: a client entry that
reaches any `[dependencies]`-backed module dies with `ModuleNotFoundError`
otherwise, and since the build is fatal that kills the whole deploy.

These drive the real ManifestBuilder against real project folders, running the
actual `jac install` and `jac build` subprocesses; no mocks."""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.project.pyvenv { get_venv_site_packages }
import from jaclang.scale.deploy.target.kubernetes.kubernetes_config {
    KubernetesConfig
}
import from jaclang.scale.deploy.target.kubernetes.manifest_builder { ManifestBuilder }

# Tiny, pure-python, zero-dependency package: enough to prove the host build
# env is populated from [dependencies] without making this a download test.
glob APP_DEP: str = "toposort",
     MISSING_DEP: str = "jac-nonexistent-package-8010";


def _builder(project_dir: str, dry_run: bool = False) -> ManifestBuilder {
    mb = ManifestBuilder(
        k8s_config=KubernetesConfig(app_name="shop", namespace="jb-shop"),
        microservices_config={"client": {"entry": "main.jac"}},
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
            '[dependencies.npm]\nreact = "^18.2.0"\nreact-dom = "^18.2.0"\n'
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


test "the host client build installs the app's declared dependencies" {
    project_dir = _project(f'{APP_DEP} = ">=1.10"', APP_DEP);
    try {
        _builder(project_dir)._build_client_bundle(project_dir);
        installed = [
            p.name
            for p in get_venv_site_packages(Path(project_dir) / ".jac" / "venv").glob(
                f"{APP_DEP}*"
            )
        ];
        built = (
            Path(project_dir) / ".jac" / "client" / "dist" / "index.html"
        ).is_file();
    } finally {
        shutil.rmtree(project_dir, ignore_errors=True);
    }

    assert installed , (
        "the deploy never installed the app's [dependencies] into the host "
        f"build env, so any client entry reaching a {APP_DEP}-backed module "
        "cannot build here"
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

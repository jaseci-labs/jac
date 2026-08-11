"""A sealed image's prebuilt serve artifacts (client dist, serve manifest)
speak only for the modules the image actually contains. A project that merely
lives in a directory nested under a sealed root - a staged user app inside a
sealed builder service, for example - must not inherit the host image's
bundle: the ancestor walk alone would hand the host's own_mod frontend to any
foreign `jac build`, which then fails with "bundle not found" because the
foreign project's dist was never populated.

These tests drive the real helpers against real on-disk sealed layouts, and
the end-to-end case runs a real `jac build --client web` subprocess from a
project nested under a decoy sealed root; no mocks."""

import json;
import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.sealed_serve {
    client_dist_for,
    sealed_root_for,
    serve_manifest_for
}
import from .test_helpers { get_jac_command }


def _sealed_root(tmp: str, manifest: (dict | None) = None) -> str {
    img_root = os.path.join(tmp, "app");
    os.makedirs(os.path.join(img_root, "_precompiled"));
    dist = os.path.join(img_root, ".jac", "client", "dist");
    os.makedirs(dist);
    if manifest is None {
        manifest = {
            "format": 5,
            "entry": {"module": "app.main", "path": "main.jac"},
            "modules": {"main.jac": {"module": "app.main", "jir": "main.jir"}}
        };
    }
    with open(
        os.path.join(img_root, "_precompiled", "MANIFEST.json"), "w", encoding="utf-8"
    ) as f {
        f.write(json.dumps(manifest));
    }
    with open(os.path.join(img_root, "main.jac"), "w", encoding="utf-8") as f {
        f.write("with entry {}\n");
    }
    with open(os.path.join(dist, "client.HOSTHASH.js"), "w", encoding="utf-8") as f {
        f.write('console.log("host image bundle");\n');
    }
    with open(
        os.path.join(img_root, ".jac", "serve_manifest.json"), "w", encoding="utf-8"
    ) as f {
        f.write('{"client": {"exports": [], "globals": []}}');
    }
    return img_root;
}


test "a sealed image's own_mod module resolves to the sealed root" {
    tmp = tempfile.mkdtemp(prefix="sealed-serve-");
    try {
        img_root = _sealed_root(tmp);
        own_mod = os.path.join(img_root, "main.jac");
        assert sealed_root_for(own_mod) == img_root;
        dist = client_dist_for(own_mod);
        assert dist is not None and any(dist.glob("client.*.js"));
        assert serve_manifest_for(own_mod) is not None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "a foreign project nested under a sealed root is not sealed" {
    tmp = tempfile.mkdtemp(prefix="sealed-serve-");
    try {
        img_root = _sealed_root(tmp);
        staged = os.path.join(img_root, ".jachome", "projects", "user", "todo");
        os.makedirs(staged);
        foreign = os.path.join(staged, "main.jac");
        with open(foreign, "w", encoding="utf-8") as f {
            f.write("with entry {}\n");
        }

        assert sealed_root_for(foreign) is None , (
            "a module the sealed manifest does not list must not adopt the "
            "host image's root"
        );
        assert client_dist_for(foreign) is None , (
            "the host image's prebuilt bundle leaked to a foreign project"
        );
        assert serve_manifest_for(foreign) is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "an unreadable sealed manifest claims no modules" {
    tmp = tempfile.mkdtemp(prefix="sealed-serve-");
    try {
        img_root = _sealed_root(tmp);
        with open(
            os.path.join(img_root, "_precompiled", "MANIFEST.json"),
            "w",
            encoding="utf-8"
        ) as f {
            f.write("{not json");
        }
        assert sealed_root_for(os.path.join(img_root, "main.jac")) is None;
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}


test "jac build inside a sealed host builds the nested project's bundle" {
    tmp = tempfile.mkdtemp(prefix="sealed-serve-e2e-");
    try {
        img_root = _sealed_root(tmp);
        staging = os.path.join(img_root, ".jachome", "projects", "user");
        os.makedirs(staging);
        jac_cmd = get_jac_command();
        created = subprocess.run(
            [*jac_cmd, "create", "todo", "--kind", "web-app"],
            cwd=staging,
            capture_output=True,
            text=True,
            timeout=300
        );
        assert created.returncode == 0 , (
            f"jac create failed: {created.stdout}\n{created.stderr}"
        );
        project = os.path.join(staging, "todo");

        built = subprocess.run(
            [*jac_cmd, "build", "main.jac", "--client", "web"],
            cwd=project,
            capture_output=True,
            text=True,
            timeout=900
        );
        assert built.returncode == 0 , (
            f"nested build failed (rc={built.returncode}):\n"
            f"{built.stdout[-800:]}\n{built.stderr[-800:]}"
        );

        dist = Path(project) / ".jac" / "client" / "dist";
        assert (dist / "index.html").is_file() , (
            "nested build produced no index.html in the project's own_mod dist"
        );
        bundles = list(dist.glob("client.*.js"));
        assert bundles , "nested build emitted no bundle in the project's dist";
        assert "host image bundle" not in bundles[0].read_text(encoding="utf-8") , "the host image's bundle leaked into the nested project";
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

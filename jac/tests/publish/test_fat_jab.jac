"""End-to-end tests for the fat jab: `jac build --fat` vendors the Python
dependency closure into the bundle, and materializing the bundle installs those
wheels offline (no PyPI). See issue #7465.

The tests build against a *local* wheelhouse (PIP_NO_INDEX + PIP_FIND_LINKS), so
they need no network: a hand-rolled pure-python wheel stands in for a PyPI dep.
"""

import io;
import os;
import sys;
import shutil;
import tarfile;
import tempfile;
import zipfile;
import from pathlib { Path }
import from subprocess { run }

glob DIST: str = "vend-demo",
     DIST_FILE: str = "vend_demo",
     PKG: str = "vend_demo",
     VERSION: str = "0.0.1";


"""Write a minimal, valid pure-python wheel for `vend_demo` into `wheelhouse`.

A wheel is just a zip with the package tree plus a `.dist-info/` carrying
METADATA / WHEEL / RECORD. RECORD entries may omit hash+size (trailing commas),
which keeps this fixture dependency-free and deterministic.
"""
def _make_wheel(wheelhouse: Path) -> Path {
    wheelhouse.mkdir(parents=True, exist_ok=True);
    dist_info = f"{DIST_FILE}-{VERSION}.dist-info";
    files = {
        f"{PKG}/__init__.py": "VALUE = 4242\n",
        f"{dist_info}/METADATA": (
            "Metadata-Version: 2.1\n" f"Name: {DIST}\n" f"Version: {VERSION}\n"
        ),
        f"{dist_info}/WHEEL": (
            "Wheel-Version: 1.0\n"
            "Generator: jac-test\n"
            "Root-Is-Purelib: true\n"
            "Tag: py3-none-any\n"
        )
    };
    record = "".join([f"{name},,\n" for name in files.keys()]);
    record += f"{dist_info}/RECORD,,\n";
    files[f"{dist_info}/RECORD"] = record;

    whl = wheelhouse / f"{DIST_FILE}-{VERSION}-py3-none-any.whl";
    with zipfile.ZipFile(whl, "w", zipfile.ZIP_DEFLATED) as zf {
        for (name, body) in files.items() {
            zf.writestr(name, body);
        }
    }
    return whl;
}


"""Write a runnable cli project that imports the vendored dep at `tmp_path`."""
def _make_project(tmp_path: Path) {
    toml = (
        '[project]\n'
        'name = "fatapp"\n'
        'version = "1.0.0"\n'
        'entry-point = "main.jac"\n\n'
        '[dependencies]\n'
        f'{DIST} = "=={VERSION}"\n'
    );
    (tmp_path / "jac.toml").write_text(toml);
    (tmp_path / "main.jac").write_text(
        f"import {PKG};\n"
        "with entry {\n"
        f"    print(f\"vend_demo.VALUE={{{PKG}.VALUE}}\");\n"
        "}\n"
    );
}


"""Env for a build/run that resolves ONLY from the local wheelhouse (no PyPI)."""
def _offline_env(wheelhouse: Path) -> dict {
    env = dict(os.environ);
    env["PIP_NO_INDEX"] = "1";
    env["PIP_FIND_LINKS"] = str(wheelhouse);
    env.pop("PIP_INDEX_URL", None);
    env.pop("PIP_EXTRA_INDEX_URL", None);
    return env;
}


test "jac build --fat vendors the dependency closure into the jab" {
    tmp_path = Path(tempfile.mkdtemp());
    original_cwd = os.getcwd();
    try {
        wheelhouse = tmp_path / "wheelhouse";
        _make_wheel(wheelhouse);
        proj = tmp_path / "proj";
        proj.mkdir();
        _make_project(proj);
        os.chdir(proj);

        result = run(
            ["jac", "build", "--as", "jab", "--fat", "--no_typecheck"],
            capture_output=True,
            text=True,
            env=_offline_env(wheelhouse)
        );
        assert result.returncode == 0 , (
            f"fat build failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
        );

        jab = proj / "dist" / "fatapp.jab";
        assert jab.is_file() , f"no jab produced: {list((proj / 'dist').glob('*'))}";

        # The vendored wheels ride inside the tarball as `_vendor/wheels/*.whl`,
        # a sibling of `_precompiled/` so the sealed manifest is untouched.
        names: list = [];
        with tarfile.open(fileobj=io.BytesIO(jab.read_bytes()), mode="r:*") as tf {
            names = tf.getnames();
        }
        wheels = [
            n
            for n in names
            if n.startswith("_vendor/wheels/") and n.endswith(".whl")
        ];
        assert any(PKG in w for w in wheels) , (
            f"vendored wheel for {PKG} not found in jab; entries: {wheels}"
        );
        assert "_vendor/VENDOR.json" in names , (
            f"vendor manifest missing; entries: {[
                n
                for n in names
                if '_vendor' in n
            ]}"
        );
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "a fat jab runs offline with its vendored dependency" {
    tmp_path = Path(tempfile.mkdtemp());
    original_cwd = os.getcwd();
    try {
        wheelhouse = tmp_path / "wheelhouse";
        _make_wheel(wheelhouse);
        proj = tmp_path / "proj";
        proj.mkdir();
        _make_project(proj);
        os.chdir(proj);

        build = run(
            ["jac", "build", "--as", "jab", "--fat", "--no_typecheck"],
            capture_output=True,
            text=True,
            env=_offline_env(wheelhouse)
        );
        assert build.returncode == 0 , (
            f"fat build failed:\nstdout: {build.stdout}\nstderr: {build.stderr}"
        );
        jab = proj / "dist" / "fatapp.jab";
        assert jab.is_file();

        # Ship the jab somewhere the wheelhouse is NOT reachable and PyPI is
        # forbidden: only the vendored wheels can satisfy the import.
        elsewhere = tmp_path / "elsewhere";
        elsewhere.mkdir();
        shipped = elsewhere / "fatapp.jab";
        shutil.copy(jab, shipped);
        shutil.rmtree(wheelhouse, ignore_errors=True);

        run_env = dict(os.environ);
        run_env["PIP_NO_INDEX"] = "1";
        os.chdir(elsewhere);
        runres = run(
            ["jac", "run", "fatapp.jab"], capture_output=True, text=True, env=run_env
        );
        assert runres.returncode == 0 , (
            f"fat jab run failed:\nstdout: {runres.stdout}\nstderr: {runres.stderr}"
        );
        assert "vend_demo.VALUE=4242" in runres.stdout , (
            f"vendored dep not importable at run time:\nstdout: {runres.stdout}\n"
            f"stderr: {runres.stderr}"
        );
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


def _pip_scripted(calls: list, args: list[str]) -> tuple[int, str] {
    calls.append(list(args));
    if args[0] == "download" {
        return (1, "ResolutionImpossible: no wheels for http-ece");
    }
    return (0, "");
}


test "native vendoring builds sdist-only deps instead of refusing the closure" {
    import functools;
    import jaclang.runtimelib.jab_vendor as jab_vendor;
    calls: list = [];
    saved = jab_vendor._pip;
    jab_vendor._pip = functools.partial(_pip_scripted, calls);
    try {
        with tempfile.TemporaryDirectory() as tmp {
            (ok, err) = jab_vendor.download_wheels(["pywebpush>=2.0.0"], Path(tmp));
        }
    } finally {
        jab_vendor._pip = saved;
    }
    assert ok , err;
    assert len(calls) == 2;
    assert calls[0][0] == "download";
    assert calls[1][0] == "wheel";
    assert "--wheel-dir" in calls[1];
}


test "cross-target vendoring still refuses when wheels are missing" {
    import functools;
    import jaclang.runtimelib.jab_vendor as jab_vendor;
    calls: list = [];
    saved = jab_vendor._pip;
    jab_vendor._pip = functools.partial(_pip_scripted, calls);
    try {
        with tempfile.TemporaryDirectory() as tmp {
            (ok, err) = jab_vendor.download_wheels(
                ["pywebpush>=2.0.0"], Path(tmp), platform_tag="manylinux2014_x86_64"
            );
        }
    } finally {
        jab_vendor._pip = saved;
    }
    assert not ok;
    assert len(calls) == 1 , "no build attempt for a cross-target closure";
}

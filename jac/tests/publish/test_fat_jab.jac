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


"""Identity helper: routes duck-typed values past the checker."""
def _as_any(v: any) -> any {
    return v;
}


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
        'entry-point = "main"\n\n'
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
def _offline_env(wheelhouse: Path) -> dict[str, any] {
    env: dict[str, str] = dict(os.environ);
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
            ["jac", "build", "--as", "jab", "--fat"],
            capture_output=True,
            text=True,
            env=_offline_env(wheelhouse)
        );
        assert result.returncode == 0 , (
            f"fat build failed:\nstdout: {result.stdout}\nstderr: {result.stderr}"
        );

        jab = proj / "dist" / "fatapp.jab";
        assert jab.is_file() , f"no jab produced: {list((proj / 'dist').`glob('*'))}";

        # The vendored wheels ride inside the tarball as `_vendor/wheels/*.whl`,
        # a sibling of `_precompiled/` so the sealed manifest is untouched.
        names: list[any] = [];
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
            ["jac", "build", "--as", "jab", "--fat"],
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

        run_env: dict[str, str] = dict(os.environ);
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


def _pip_scripted(
    calls: list[any],
    args: list[str],
    missing: str = "http-ece>=1.1.0",
    fits: bool = True
) -> tuple[int, str] {
    calls.append(list(args));
    if args[0] == "wheel" {
        name = missing.split(">")[0].split("=")[0].replace("-", "_");
        tag = "py3-none-any" if fits else "cp39-abi3-macosx_10_12_universal2";
        wheel_dir = Path(args[args.index("--wheel-dir") + 1]);
        (wheel_dir / f"{name}-1.0-{tag}.whl").write_bytes(b"");
        return (0, f"Successfully built {name}");
    }
    if "--find-links" in args and fits {
        return (0, "");
    }
    return (
        1,
        f"ERROR: Could not find a version that satisfies the requirement {missing} "
        f"(from versions: none)\nERROR: No matching distribution found for {missing}"
    );
}


def _pip_flat(calls: list[any], args: list[str], out: str = "") -> tuple[int, str] {
    calls.append(list(args));
    return (0 if not out else 1, out);
}


def _platforms(argv: list[str]) -> list[str] {
    return [
        argv[i + 1]
        for i in range(len(argv) - 1)
        if argv[i] == "--platform"
    ];
}


test "the manylinux ladder runs from the pod glibc down through every legacy alias" {
    import from jaclang.dist.jab_vendor { WheelTarget, manylinux_tags }
    x86 = manylinux_tags("x86_64", (2, 36));
    assert x86[0] == "manylinux_2_36_x86_64" , x86;
    assert x86[-2:] == ["manylinux_2_5_x86_64", "manylinux1_x86_64"] , x86;
    assert "manylinux_2_37_x86_64" not in x86;
    assert x86.index("manylinux2014_x86_64") == x86.index("manylinux_2_17_x86_64") + 1;
    assert x86.index("manylinux2010_x86_64") == x86.index("manylinux_2_12_x86_64") + 1;
    assert x86.index("manylinux_2_28_x86_64") < x86.index("manylinux_2_17_x86_64");
    arm = manylinux_tags("aarch64", (2, 36));
    assert arm[0] == "manylinux_2_36_aarch64" , arm;
    assert arm[-2:] == ["manylinux_2_17_aarch64", "manylinux2014_aarch64"] , arm;
    assert not any(["manylinux2010" in t or "manylinux1_" in t for t in arm]) , arm;
    target = WheelTarget(arch="x86_64", python_version="3.12", glibc=(2, 36));
    assert target.platform_tag() == "manylinux_2_36_x86_64";
    assert target.platform_tags() == x86 + ["linux_x86_64"];
    assert target.describe() == "manylinux_2_36_x86_64 on python 3.12";
}


test "download_wheels asks pip for the whole ladder, python version and implementation" {
    import functools;
    import jaclang.dist.jab_vendor as jab_vendor;
    calls: list[any] = [];
    saved = jab_vendor._pip;
    jab_vendor._pip = _as_any(functools.partial(_pip_flat, calls));
    target = jab_vendor.WheelTarget(
        arch="x86_64", python_version="3.12", glibc=(2, 36)
    );
    try {
        with tempfile.TemporaryDirectory() as tmp {
            result = jab_vendor.download_wheels(
                ["watchdog>=3.0.0"], Path(tmp), target=target
            );
        }
    } finally {
        jab_vendor._pip = saved;
    }
    assert result.ok , result.detail;
    assert len(calls) == 1;
    argv = calls[0];
    assert argv[0] == "download" and "--only-binary=:all:" in argv , argv;
    assert argv[argv.index("--python-version") + 1] == "3.12" , argv;
    assert argv[argv.index("--implementation") + 1] == "cp" , argv;
    assert "--find-links" not in argv , "a fresh closure resolves against the index alone";
    platforms = _platforms(argv);
    assert platforms == target.platform_tags() , platforms;
    assert "manylinux2014_x86_64" in platforms and "manylinux_2_17_x86_64" in platforms;
    assert "manylinux_2_36_x86_64" in platforms
        and "manylinux_2_28_x86_64" in platforms;
    assert argv[-1] == "watchdog>=3.0.0";
}


test "a host build without a target adds no platform pins" {
    import functools;
    import jaclang.dist.jab_vendor as jab_vendor;
    calls: list[any] = [];
    saved = jab_vendor._pip;
    jab_vendor._pip = _as_any(functools.partial(_pip_flat, calls));
    try {
        with tempfile.TemporaryDirectory() as tmp {
            result = jab_vendor.download_wheels(["pywebpush>=2.0.0"], Path(tmp));
        }
    } finally {
        jab_vendor._pip = saved;
    }
    assert result.ok;
    assert "--platform" not in calls[0] and "--python-version" not in calls[0] , calls[
        0
    ];
}


test "an sdist-only dep is built on the host and the closure re-resolved through it" {
    import functools;
    import jaclang.dist.jab_vendor as jab_vendor;
    calls: list[any] = [];
    saved = jab_vendor._pip;
    jab_vendor._pip = _as_any(functools.partial(_pip_scripted, calls));
    target = jab_vendor.WheelTarget(
        arch="x86_64", python_version="3.12", glibc=(2, 36)
    );
    try {
        with tempfile.TemporaryDirectory() as tmp {
            result = jab_vendor.download_wheels(
                ["pywebpush>=2.0.0"], Path(tmp), target=target
            );
            left = sorted([p.name for p in Path(tmp).`glob("*.whl")]);
        }
    } finally {
        jab_vendor._pip = saved;
    }
    assert result.ok , result.detail;
    assert result.missing == [];
    assert [c[0] for c in calls] == ["download", "wheel", "download"] , calls;
    assert calls[1][:4] == ["wheel", "--no-deps", "--wheel-dir", calls[1][3]] , calls[
        1
    ];
    assert calls[1][-1] == "http-ece>=1.1.0" , "only the missing dep is built, with its constraint";
    assert calls[2][calls[2].index("--find-links") + 1] == calls[1][3] , calls[2];
    assert _platforms(calls[2]) == target.platform_tags() , "the retry keeps the target pins";
    assert left == ["http_ece-1.0-py3-none-any.whl"] , left;
}


test "a host-built wheel that does not fit the target is dropped and named" {
    import functools;
    import jaclang.dist.jab_vendor as jab_vendor;
    calls: list[any] = [];
    saved = jab_vendor._pip;
    jab_vendor._pip = _as_any(
        functools.partial(_pip_scripted, calls, missing="bcrypt==5.0.0", fits=False)
    );
    target = jab_vendor.WheelTarget(
        arch="x86_64", python_version="3.12", glibc=(2, 36)
    );
    try {
        with tempfile.TemporaryDirectory() as tmp {
            result = jab_vendor.download_wheels(
                ["bcrypt==5.0.0"], Path(tmp), target=target
            );
            left = sorted([p.name for p in Path(tmp).`glob("*.whl")]);
        }
    } finally {
        jab_vendor._pip = saved;
    }
    assert not result.ok;
    assert result.missing == ["bcrypt"] , result.missing;
    assert [c[0] for c in calls] == ["download", "wheel", "download"] , calls;
    assert left == [] , "an unfit host wheel must not ship";
    assert "bcrypt-1.0-cp39-abi3-macosx_10_12_universal2.whl" in result.detail , result.detail;
    assert "manylinux_2_36_x86_64 on python 3.12" in result.detail , result.detail;
}


test "pip's conflict report names every package without a distribution" {
    import from jaclang.dist.jab_vendor { _missing_requirements }
    conflict = (
        "ERROR: Cannot install pywebpush==2.4.0 and pywebpush==2.5.0 because these "
        "package versions have conflicting dependencies.\n\n"
        "The conflict is caused by:\n"
        "    pywebpush 2.5.0 depends on http-ece>=1.1.0\n"
        "    pywebpush 2.4.0 depends on http-ece>=1.1.0\n\n"
        "Additionally, some packages in these conflicts have no matching "
        "distributions available for your environment:\n"
        "    http-ece\n"
        "    Some_Other.Pkg\n\n"
        "To fix this you could try to:\n"
        "1. loosen the range of package versions you've specified\n\n"
        "ERROR: ResolutionImpossible: for help visit https://pip.pypa.io/"
    );
    assert _missing_requirements(conflict)
        == {"http-ece": "http-ece", "some-other-pkg": "Some_Other.Pkg"} , _missing_requirements(
        conflict
    );
    single = (
        "ERROR: Could not find a version that satisfies the requirement "
        "Foo_Bar[extra]>=1.0 (from baz) (from versions: none)\n"
        "ERROR: No matching distribution found for Foo_Bar[extra]>=1.0"
    );
    assert _missing_requirements(single) == {"foo-bar": "Foo_Bar[extra]>=1.0"};
    assert _missing_requirements("ERROR: HTTP error 503 while getting the index") == {};
}


test "a failure pip does not pin on a missing wheel is reported verbatim, with no build" {
    import functools;
    import jaclang.dist.jab_vendor as jab_vendor;
    calls: list[any] = [];
    saved = jab_vendor._pip;
    jab_vendor._pip = _as_any(
        functools.partial(
            _pip_flat, calls, out="ERROR: HTTP error 503 while getting the index"
        )
    );
    try {
        with tempfile.TemporaryDirectory() as tmp {
            result = jab_vendor.download_wheels(["pywebpush>=2.0.0"], Path(tmp));
        }
    } finally {
        jab_vendor._pip = saved;
    }
    assert not result.ok;
    assert result.missing == [];
    assert result.detail == "ERROR: HTTP error 503 while getting the index";
    assert len(calls) == 1 , "nothing to build when pip named no missing package";
}

"""Tests for the jaclang.publish pipeline.

Covers the four new modules added in this branch:
  metadata  — METADATA 2.4 string generation
  record    — RECORD CSV with SHA-256 fingerprints
  wheel_meta — WHEEL file and entry_points.txt generators
  sources   — source-file collector
  builder   — WheelBuilder end-to-end (wheel + sdist)
"""

import hashlib;
import base64;
import csv;
import io;
import tarfile;
import tomllib;
import zipfile;
import json;
import tempfile;
import shutil;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.publish.metadata {
    normalize_package_name,
    normalize_constraint,
    generate_metadata,
    generate_pyproject_toml
}
import from jaclang.publish.record { record_entry_from_bytes, generate_record }
import from jaclang.publish.wheel_meta {
    generate_wheel_file,
    generate_entry_points,
    wheel_filename,
    dist_info_dirname,
    sdist_filename
}
import from jaclang.publish.sources {
    SourceFile,
    read_source_file,
    collect_source_files
}
import from jaclang.publish.builder { WheelBuilder }


# Helpers --------------------------------------------------------------------------
def sha256_b64(data: bytes) -> str {
    b64 = base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"=");
    return f"sha256={b64.decode('ascii')}";
}

def scaffold_pkg(pkg_dir: Path, name: str = "mypkg") {
    pkg = pkg_dir / name;
    pkg.mkdir(exist_ok=True);
    (pkg / "__init__.jac").write_text(f"# {name}\n");
    (pkg / "core.jac").write_text("# core\n");
}

def pkg_config_with_include(
    pkg_dir: Path, name: str = "mypkg", version: str = "1.0.0"
) -> JacConfig {
    toml = '[project]\nname = "' + name + '"\nversion = "' + version + '"\nrequires-python = ">=3.11"\n\n[project.include]\npackages = ["' + name + '"]\n';
    cfg = JacConfig.from_toml_str(toml);
    cfg.project_root = pkg_dir;
    return cfg;
}

# metadata --------------------------------------------------------------------------
test "normalize_package_name lowercases and collapses separators" {
    assert normalize_package_name("My_Pkg.Name") == "my-pkg-name";
    assert normalize_package_name("JAC--Lang") == "jac-lang";
}

test "normalize_constraint converts npm caret tilde and wildcard" {
    assert normalize_constraint("^1.2.3") == ">=1.2.3,<2.0.0";
    assert normalize_constraint("^0.7.1") == ">=0.7.1,<0.8.0";
    assert normalize_constraint("~1.2") == ">=1.2.0,<1.3.0";
    assert normalize_constraint("*") == "";
    assert normalize_constraint(">=1.0") == ">=1.0";
}

test "generate_metadata produces correct METADATA 2.4 output" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "mypkg"\nversion = "1.2.3"\nrequires-python = ">=3.11"\nlicense = "MIT"\n\n[dependencies]\nrequests = ">=2.28.0"\nnumpy = "^1.24.0"\n\n[optional-dependencies.video]\nopencv-python-headless = ">=4.0"\n'
    );
    meta = generate_metadata(cfg);

    # required headers
    assert "Metadata-Version: 2.4" in meta;
    assert "Name: mypkg" in meta;
    assert "Version: 1.2.3" in meta;
    assert "Requires-Python: >=3.11" in meta;
    assert "License-Expression: MIT" in meta;
    # runtime deps (including caret normalisation)
    assert "Requires-Dist: requests>=2.28.0" in meta;
    assert "Requires-Dist: numpy>=1.24.0,<2.0.0" in meta;
    # optional deps
    assert "Provides-Extra: video" in meta;
    assert 'opencv-python-headless>=4.0; extra == "video"' in meta;
}

test "generate_metadata emits Classifier headers in order" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "mypkg"\nversion = "1.0.0"\nclassifiers = [\n  "Programming Language :: Python :: 3",\n  "License :: OSI Approved :: MIT License",\n  "Framework :: Jac",\n]\n'
    );
    meta = generate_metadata(cfg);
    lines = [
        l
        for l in meta.splitlines()
        if l.startswith("Classifier:")
    ];
    assert lines == [
        "Classifier: Programming Language :: Python :: 3",
        "Classifier: License :: OSI Approved :: MIT License",
        "Classifier: Framework :: Jac",

    ];
}

test "generate_metadata raises when package section missing" {
    raised = False;
    try {
        generate_metadata(JacConfig());
    } except ValueError {
        raised = True;
    }
    assert raised;
}

# record --------------------------------------------------------------------------
test "record_entry_from_bytes has correct sha256 and size" {
    data = b"hello jac";
    entry = record_entry_from_bytes("pkg/main.jac", data);
    assert entry.path == "pkg/main.jac";
    assert entry.hash_value == sha256_b64(data);
    assert entry.size == len(data);
    assert "=" not in entry.hash_value[len("sha256="):];
}

test "generate_record self-entry last with empty hash and unix line endings" {
    entries = [record_entry_from_bytes("f.jac", b"x")];
    record_path = "pkg-1.0.dist-info/RECORD";
    text = generate_record(entries, record_path);
    rows = [
        r
        for r in csv.reader(io.StringIO(text))
        if r
    ];
    last = rows[-1];
    assert last[0] == record_path;
    assert last[1] == "" and last[2] == "";
    assert "\r\n" not in text;
}


# wheel_meta --------------------------------------------------------------------------
test "generate_wheel_file has required headers and ends with newline" {
    content = generate_wheel_file();
    assert "Wheel-Version: 1.0" in content;
    assert "Root-Is-Purelib: true" in content;
    assert "Tag: py3-none-any" in content;
    assert content.endswith("\n");
}

test "generate_entry_points maps scripts to console_scripts" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "p"\nversion = "1.0.0"\n\n[entrypoints.scripts]\nmycli = "p.cli:main"\n\n[entrypoints.jac]\nplugin = "p:Plugin"\n'
    );
    ep = generate_entry_points(cfg);
    assert "[console_scripts]" in ep;
    assert "[jac]" in ep;
    assert "mycli = p.cli:main" in ep;
}

test "wheel_filename and dist_info_dirname are consistent" {
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "mypkg"\nversion = "2.0.0"\nrequires-python = ">=3.11"\n'
    );
    assert wheel_filename(cfg) == "mypkg-2.0.0-py3-none-any.whl";
    assert dist_info_dirname(cfg) == "mypkg-2.0.0.dist-info";
}


# sources --------------------------------------------------------------------------
test "read_source_file returns preloaded content and reads from disk" {
    sf_mem = SourceFile(wheel_path="x.jac", content=b"data");
    assert read_source_file(sf_mem) == b"data";

    tmpdir = tempfile.mkdtemp();
    try {
        f = Path(tmpdir) / "t.jac";
        f.write_bytes(b"original");
        sf_disk = SourceFile(wheel_path="t.jac", source_path=f);
        assert read_source_file(sf_disk) == b"original";
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "collect_source_files gathers jac files and excludes build artifacts" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        pkg = proj / "mypkg";
        pkg.mkdir();
        (pkg / "main.jac").write_text("# main");
        (pkg / "helper.py").write_text("# py");
        (pkg / "stale.pyc").write_bytes(bytes([0]));
        pycache = pkg / "__pycache__";
        pycache.mkdir();
        (pycache / "main.cpython-312.pyc").write_bytes(bytes([0]));
        cfg = pkg_config_with_include(proj, "mypkg");
        files = collect_source_files(cfg, project_root=proj);
        paths = [sf.wheel_path for sf in files];
        assert any("main.jac" in p for p in paths);
        assert any("helper.py" in p for p in paths);
        assert not any(".pyc" in p for p in paths);
        assert not any("__pycache__" in p for p in paths);
        assert not any("\\" in p for p in paths);
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "collect_source_files excludes tests directory from the package" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        pkg = proj / "mypkg";
        pkg.mkdir();
        (pkg / "main.jac").write_text("# main");
        testsdir = pkg / "tests";
        testsdir.mkdir();
        (testsdir / "fixture.jac").write_text("# fixture");
        cfg = pkg_config_with_include(proj, "mypkg");
        files = collect_source_files(cfg, project_root=proj);
        paths = [sf.wheel_path for sf in files];
        assert any("main.jac" in p for p in paths);
        assert not any("tests/" in p for p in paths);
        assert not any("fixture.jac" in p for p in paths);
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "collect_source_files raises without project root or package section" {
    cfg_no_root = JacConfig.from_toml_str(
        "[project]\nname = \"p\"\nversion = \"1.0.0\"\n"
    );
    raised = False;
    try {
        collect_source_files(cfg_no_root);
    } except ValueError {
        raised = True;
    }
    assert raised;

    tmpdir = tempfile.mkdtemp();
    try {
        cfg_no_pkg = JacConfig();
        cfg_no_pkg.project_root = Path(tmpdir);
        raised2 = False;
        try {
            collect_source_files(cfg_no_pkg);
        } except ValueError {
            raised2 = True;
        }
        assert raised2;
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


test "collect_source_files flat layout maps root files under package with synth init" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        (proj / "main.jac").write_text("# main\n");
        (proj / "helper.py").write_text("# helper\n");
        sub = proj / "tests";
        sub.mkdir();
        (sub / "test_x.jac").write_text("# test\n");
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "flatpkg"\nversion = "1.0.0"\n'
        );
        cfg.project_root = proj;
        files = collect_source_files(cfg, project_root=proj);
        paths = [sf.wheel_path for sf in files];
        assert "flatpkg/main.jac" in paths;
        assert "flatpkg/helper.py" in paths;
        assert "flatpkg/__init__.py" in paths;
        assert not any("tests/" in p for p in paths);
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "collect_source_files flat layout keeps existing __init__.jac and skips synth" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        (proj / "__init__.jac").write_text("# init\n");
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "flatinit"\nversion = "1.0.0"\n'
        );
        cfg.project_root = proj;
        files = collect_source_files(cfg, project_root=proj);
        paths = [sf.wheel_path for sf in files];
        assert "flatinit/__init__.jac" in paths;
        assert "flatinit/__init__.py" not in paths;
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


# builder — end-to-end --------------------------------------------------------------------------
test "WheelBuilder.build produces a valid whl with required dist-info files" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        scaffold_pkg(proj);
        cfg = pkg_config_with_include(proj);
        data = WheelBuilder(config=cfg, project_root=proj).build();

        with zipfile.ZipFile(io.BytesIO(data)) as zf {
            names = zf.namelist();
            di = dist_info_dirname(cfg);
            assert f"{di}/METADATA" in names;
            assert f"{di}/WHEEL" in names;
            assert f"{di}/RECORD" in names;
            assert any(n.endswith(".py") for n in names);
            assert not any(n.endswith(".jac") for n in names);
            assert "Name: mypkg" in zf.read(f"{di}/METADATA").decode();
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.build flat layout with __init__.jac transpiles without collision" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        (proj / "__init__.jac").write_text("def hi() {\n    print(\"hi\");\n}\n");
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "flatinit"\nversion = "1.0.0"\n'
        );
        cfg.project_root = proj;
        data = WheelBuilder(config=cfg, project_root=proj).build();
        with zipfile.ZipFile(io.BytesIO(data)) as zf {
            names = zf.namelist();
            assert "flatinit/__init__.py" in names;
            assert not any(n.endswith(".jac") for n in names);
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.build skips inlined annex files when transpiling" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        pkg = proj / "mypkg";
        pkg.mkdir();
        (pkg / "greeter.jac").write_text("def greet() -> str;\n");
        (pkg / "greeter.impl.jac").write_text("impl greet {\n    return \"hi\";\n}\n");
        (pkg / "greeter.test.jac").write_text("test \"t\" {\n    assert 1 == 1;\n}\n");
        cfg = pkg_config_with_include(proj, "mypkg");
        data = WheelBuilder(config=cfg, project_root=proj).build();
        with zipfile.ZipFile(io.BytesIO(data)) as zf {
            names = zf.namelist();
            assert "mypkg/greeter.py" in names;
            assert not any(n.endswith(".impl.py") for n in names);
            assert not any(n.endswith(".test.py") for n in names);
            assert not any(n.endswith(".jac") for n in names);
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.build is reproducible" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        scaffold_pkg(proj);
        cfg = pkg_config_with_include(proj);
        builder = WheelBuilder(config=cfg, project_root=proj);
        assert builder.build() == builder.build();
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.build_to writes file with correct name" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        scaffold_pkg(proj, "testpkg");
        cfg = pkg_config_with_include(proj, "testpkg", "2.0.0");
        result = WheelBuilder(config=cfg, project_root=proj).build_to(proj / "dist");
        assert result.exists();
        assert result.name == wheel_filename(cfg);
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.install_editable writes pth and dist-info" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        src = proj / "src";
        src.mkdir();
        site = proj / "site-packages";
        site.mkdir();
        cfg = pkg_config_with_include(proj);
        pth = WheelBuilder(config=cfg, project_root=proj).install_editable(src, site);
        assert pth.exists() and pth.suffix == ".pth";
        assert str(src) in pth.read_text();
        di_dir = site / dist_info_dirname(cfg);
        assert (di_dir / "METADATA").exists();
        assert (di_dir / "RECORD").exists();
        assert json.loads((di_dir / "direct_url.json").read_text())["dir_info"][
            "editable"
        ];
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder raises without package section or project root" {
    raised1 = False;
    try {
        WheelBuilder(config=JacConfig(), project_root=Path("/tmp")).build();
    } except ValueError {
        raised1 = True;
    }
    assert raised1;

    cfg = JacConfig.from_toml_str("[project]\nname = \"p\"\nversion = \"1.0.0\"\n");
    raised2 = False;
    try {
        WheelBuilder(config=cfg, project_root=None).build();
    } except ValueError {
        raised2 = True;
    }
    assert raised2;
}


# sdist (generate_pyproject_toml + build_sdist / build_sdist_to) -----------------
test "sdist_filename applies full name normalisation" {
    # Regression: was using name.replace('-','_') which left dots/uppercase intact.
    cfg = JacConfig.from_toml_str('[project]\nname = "My.Pkg"\nversion = "1.0.0"\n');
    assert sdist_filename(cfg) == "my_pkg-1.0.0.tar.gz";
}

test "generate_pyproject_toml produces valid TOML covering structure, deps, and escaping" {
    # One config that exercises all three concerns together:
    # - required build-system + project table structure
    # - optional/dev dependencies (fix #6 regression)
    # - double-quote escaping in license/keywords/classifiers (fixes #2-5 regression)
    cfg = JacConfig.from_toml_str(
        '[project]\nname = "mypkg"\nversion = "1.2.3"\nrequires-python = ">=3.11"\n'
        'license = "MIT \\"Modified\\""\n'
        'keywords = ["key\\"word"]\n'
        'classifiers = ["Dev :: \\"Alpha\\""]\n\n'
        '[dependencies]\nrequests = ">=2.28"\n\n'
        '[optional-dependencies.video]\nopencv = ">=4.0"\n\n'
        '[dev-dependencies]\npytest = ">=7.0"\n'
    );
    toml_str = generate_pyproject_toml(cfg);
    tomllib.loads(toml_str);  # raises TOMLDecodeError on any invalid TOML

    # structure
    assert 'build-backend = "_jac_build"' in toml_str;
    assert "requires = []" in toml_str;
    assert 'name = "mypkg"' in toml_str;
    assert 'version = "1.2.3"' in toml_str;

    # optional and dev deps
    assert '[project.optional-dependencies]' in toml_str;
    assert 'video = [' in toml_str;
    assert 'opencv' in toml_str;
    assert 'dev = [' in toml_str;
    assert 'pytest' in toml_str;
}

test "WheelBuilder.build_sdist top-level directory matches filename stem (PEP 625)" {
    # Every member path must start with <stem>/ where stem == sdist_filename without .tar.gz.
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        scaffold_pkg(proj);
        cfg = pkg_config_with_include(proj);
        data = WheelBuilder(config=cfg, project_root=proj).build_sdist();
        stem = sdist_filename(cfg)[:-len(".tar.gz")];
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
            for member in tf.getmembers() {
                assert member.name.startswith(stem + "/") , (
                    f"member '{member.name}' not under expected prefix '{stem}/'"
                );
            }
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.build_sdist contains required files and valid PKG-INFO" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        scaffold_pkg(proj);
        cfg = pkg_config_with_include(proj);
        data = WheelBuilder(config=cfg, project_root=proj).build_sdist();
        extract_dir = proj / "extracted";
        with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as tf {
            names = tf.getnames();
            assert any(n.endswith("/PKG-INFO") for n in names);
            assert any(n.endswith("/pyproject.toml") for n in names);
            assert any(n.endswith("/_jac_build.py") for n in names);
            assert any(n.endswith(".py") for n in names);
            assert not any(n.endswith(".jac") for n in names);
            tf.extractall(path=str(extract_dir), filter="data");
        }
        pkg_info_files = list(extract_dir.rglob("PKG-INFO"));
        assert len(pkg_info_files) == 1;
        pkg_info = pkg_info_files[0].read_text("utf-8");
        assert "Name: mypkg" in pkg_info;
        assert "Version: 1.0.0" in pkg_info;
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.build_sdist is reproducible" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        scaffold_pkg(proj);
        cfg = pkg_config_with_include(proj);
        builder = WheelBuilder(config=cfg, project_root=proj);
        assert builder.build_sdist() == builder.build_sdist();
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.build_sdist_to writes file with correct name" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        scaffold_pkg(proj, "testpkg");
        cfg = pkg_config_with_include(proj, "testpkg", "2.0.0");
        result = WheelBuilder(config=cfg, project_root=proj).build_sdist_to(
            proj / "dist"
        );
        assert result.exists();
        assert result.name == sdist_filename(cfg);
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}


# py_imports — wheel-layout import rewriting -----------------------------------------------------
test "wheel_module_name maps wheel paths to dotted module names" {
    import from jaclang.publish.py_imports { wheel_module_name }
    assert wheel_module_name("pkg/mod.py") == "pkg.mod";
    assert wheel_module_name("pkg/sub/mod.py") == "pkg.sub.mod";
    assert wheel_module_name("pkg/__init__.py") == "pkg";
}

test "rewrite_imports repoints project imports and leaves stdlib alone" {
    import os;
    import from jaclang.publish.py_imports { rewrite_imports }
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        (proj / "helper.jac").write_text("def hi() -> int {\n    return 1;\n}\n");
        (proj / "main.jac").write_text("import helper;\n");
        module_map = {
            os.path.normpath(os.path.abspath(str(proj / "helper.jac"))): (
                "flatpkg.helper"
            ),
            os.path.normpath(os.path.abspath(str(proj / "main.jac"))): ("flatpkg.main"),

        };
        src = (
            "from __future__ import annotations\n" + "import os\n" + "import helper\n" + "import helper as h\n" + "from helper import hi\n"
        );
        out = rewrite_imports(src, proj / "main.jac", module_map);
        assert "import os\n" in out;
        assert "from flatpkg import helper\n" in out;
        assert "import flatpkg.helper as h\n" in out;
        assert "from flatpkg.helper import hi\n" in out;
        assert "\nimport helper\n" not in out;
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder rewrites sibling imports so the installed wheel imports cleanly" {
    import subprocess;
    import sys;
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        (proj / "helper.jac").write_text(
            "def helper_fn() -> int {\n    return 7;\n}\n"
        );
        (proj / "main.jac").write_text(
            "import helper;\n\ndef use() -> int {\n" + "    return helper.helper_fn();\n}\n"
        );
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "puredemo"\nversion = "0.1.0"\n'
        );
        cfg.project_root = proj;
        data = WheelBuilder(config=cfg, project_root=proj).build();
        site = proj / "site";
        with zipfile.ZipFile(io.BytesIO(data)) as zf {
            zf.extractall(path=str(site));
            main_py = zf.read("puredemo/main.py").decode("utf-8");
        }
        assert "from puredemo import helper" in main_py;
        result = subprocess.run(
            [
                sys.executable,
                "-c",
                f"import sys; sys.path.insert(0, {str(site)!r}); " + "import puredemo.main as m; print(m.use())",

            ],
            capture_output=True,
            text=True,
        );
        assert result.returncode == 0 , result.stderr;
        assert result.stdout.strip() == "7";
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder skips client codespace files with a record" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        pkg = proj / "mypkg";
        pkg.mkdir();
        (pkg / "core.jac").write_text("def go() -> int {\n    return 1;\n}\n");
        (pkg / "view.cl.jac").write_text("def View() -> None {}\n");
        cfg = pkg_config_with_include(proj, "mypkg");
        builder = WheelBuilder(config=cfg, project_root=proj);
        data = builder.build();
        with zipfile.ZipFile(io.BytesIO(data)) as zf {
            names = zf.namelist();
            assert "mypkg/core.py" in names;
            assert not any("view" in n for n in names);
        }
        assert builder.skipped_codespace == ["mypkg/view.cl.jac"];
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder vendors the jac runtime when transpiled code needs it" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        (proj / "main.jac").write_text(
            "node Thing {\n    has n: int = 1;\n}\n\n" + "def use() -> int {\n    return Thing().n;\n}\n"
        );
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "vendemo"\nversion = "0.1.0"\n'
        );
        cfg.project_root = proj;
        builder = WheelBuilder(config=cfg, project_root=proj);
        data = builder.build();
        with zipfile.ZipFile(io.BytesIO(data)) as zf {
            names = zf.namelist();
            assert "vendemo/_jac_vendor/jaclang/__init__.py" in names;
            assert "vendemo/_jac_vendor/jaclang/jac0core/jaclib.py" in names;
            init_py = zf.read("vendemo/__init__.py").decode("utf-8");
            top_level = zf.read("vendemo-0.1.0.dist-info/top_level.txt").decode(
                "utf-8"
            );
        }
        assert "_jac_use_vendored_runtime()" in init_py;
        assert top_level.strip() == "vendemo";
        assert builder.vendored_runtime_modules > 0;
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder honors an explicit jaclang dependency instead of vendoring" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        (proj / "main.jac").write_text("node Thing {\n    has n: int = 1;\n}\n");
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "hostdemo"\nversion = "0.1.0"\n\n'
            '[dependencies]\njaclang = ">=0.30"\n'
        );
        cfg.project_root = proj;
        builder = WheelBuilder(config=cfg, project_root=proj);
        data = builder.build();
        with zipfile.ZipFile(io.BytesIO(data)) as zf {
            assert not any("_jac_vendor" in n for n in zf.namelist());
        }
        assert builder.vendored_runtime_modules == 0;
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "sdist build backend rebuilds the wheel with stdlib only" {
    import subprocess;
    import sys;
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        scaffold_pkg(proj);
        cfg = pkg_config_with_include(proj);
        builder = WheelBuilder(config=cfg, project_root=proj);
        sdist = builder.build_sdist();
        extract = proj / "extract";
        with tarfile.open(fileobj=io.BytesIO(sdist), mode="r:gz") as tf {
            tf.extractall(path=str(extract), filter="data");
        }
        sdist_root = next(extract.iterdir());
        out_dir = proj / "rebuilt";
        out_dir.mkdir();
        result = subprocess.run(
            [
                sys.executable,
                "-I",
                "-c",
                "import sys; sys.path.insert(0, '.'); import _jac_build; " + f"print(_jac_build.build_wheel({str(
                    out_dir
                )!r}))",

            ],
            capture_output=True,
            text=True,
            cwd=str(sdist_root),
        );
        assert result.returncode == 0 , result.stderr;
        rebuilt = out_dir / result.stdout.strip();
        assert rebuilt.exists();
        direct = builder.build();
        with zipfile.ZipFile(io.BytesIO(direct)) as zf_direct {
            with zipfile.ZipFile(str(rebuilt)) as zf_rebuilt {
                assert sorted(zf_direct.namelist()) == sorted(zf_rebuilt.namelist());
            }
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "collect_source_files flat layout collects subdirectories recursively" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        (proj / "main.jac").write_text("# main\n");
        sub = proj / "utils";
        sub.mkdir();
        (sub / "tools.jac").write_text("# tools\n");
        for nonpkg in ["docs", "examples", "scripts"] {
            d = proj / nonpkg;
            d.mkdir();
            (d / "extra.jac").write_text("# extra\n");
        }
        cfg = JacConfig.from_toml_str(
            '[project]\nname = "flatdeep"\nversion = "1.0.0"\n'
        );
        cfg.project_root = proj;
        files = collect_source_files(cfg, project_root=proj);
        paths = [sf.wheel_path for sf in files];
        assert "flatdeep/main.jac" in paths;
        assert "flatdeep/utils/tools.jac" in paths;
        assert not any("extra.jac" in p for p in paths);
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

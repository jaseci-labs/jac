"""Tests for the jaclang.publish pipeline.

Covers the four new modules added in this branch:
  metadata  — METADATA 2.4 string generation
  record    — RECORD CSV with SHA-256 fingerprints
  wheel_meta — WHEEL file and entry_points.txt generators
  sources   — source-file collector
  builder   — WheelBuilder end-to-end
"""

import hashlib;
import base64;
import csv;
import io;
import zipfile;
import json;
import tempfile;
import shutil;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.publish.metadata {
    normalize_package_name,
    normalize_constraint,
    generate_metadata
}
import from jaclang.publish.record { record_entry_from_bytes, generate_record }
import from jaclang.publish.wheel_meta {
    generate_wheel_file,
    generate_entry_points,
    wheel_filename,
    dist_info_dirname
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

def scaffold_pkg(root: Path, name: str = "mypkg") {
    pkg = root / name;
    pkg.mkdir(exist_ok=True);
    (pkg / "__init__.jac").write_text(f"# {name}\n");
    (pkg / "core.jac").write_text("# core\n");
}

def pkg_config_with_include(
    root: Path, name: str = "mypkg", version: str = "1.0.0"
) -> JacConfig {
    toml = '[package]\nname = "' + name + '"\nversion = "' + version + '"\nrequires-python = ">=3.11"\n\n[package.include]\npackages = ["' + name + '"]\n';
    cfg = JacConfig.from_toml_str(toml);
    cfg.project_root = root;
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
        '[package]\nname = "mypkg"\nversion = "1.2.3"\nrequires-python = ">=3.11"\nlicense = "MIT"\n\n[dependencies]\nrequests = ">=2.28.0"\nnumpy = "^1.24.0"\n\n[optional-dependencies.video]\nopencv-python-headless = ">=4.0"\n'
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
        '[package]\nname = "p"\nversion = "1.0.0"\n\n[entrypoints.scripts]\nmycli = "p.cli:main"\n\n[entrypoints.jac]\nplugin = "p:Plugin"\n'
    );
    ep = generate_entry_points(cfg);
    assert "[console_scripts]" in ep;
    assert "[jac]" in ep;
    assert "mycli = p.cli:main" in ep;
}

test "wheel_filename and dist_info_dirname are consistent" {
    cfg = JacConfig.from_toml_str(
        '[package]\nname = "mypkg"\nversion = "2.0.0"\nrequires-python = ">=3.11"\n'
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
        root = Path(tmpdir);
        pkg = root / "mypkg";
        pkg.mkdir();
        (pkg / "main.jac").write_text("# main");
        (pkg / "helper.py").write_text("# py");
        (pkg / "stale.pyc").write_bytes(bytes([0]));
        pycache = pkg / "__pycache__";
        pycache.mkdir();
        (pycache / "main.cpython-312.pyc").write_bytes(bytes([0]));
        cfg = pkg_config_with_include(root, "mypkg");
        files = collect_source_files(cfg, project_root=root);
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

test "collect_source_files raises without project root or package section" {
    cfg_no_root = JacConfig.from_toml_str(
        "[package]\nname = \"p\"\nversion = \"1.0.0\"\n"
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


# builder — end-to-end --------------------------------------------------------------------------
test "WheelBuilder.build produces a valid whl with required dist-info files" {
    tmpdir = tempfile.mkdtemp();
    try {
        root = Path(tmpdir);
        scaffold_pkg(root);
        cfg = pkg_config_with_include(root);
        data = WheelBuilder(config=cfg, project_root=root).build();

        with zipfile.ZipFile(io.BytesIO(data)) as zf {
            names = zf.namelist();
            di = dist_info_dirname(cfg);
            assert f"{di}/METADATA" in names;
            assert f"{di}/WHEEL" in names;
            assert f"{di}/RECORD" in names;
            assert any(n.endswith(".jac") for n in names);
            assert "Name: mypkg" in zf.read(f"{di}/METADATA").decode();
        }
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.build is reproducible" {
    tmpdir = tempfile.mkdtemp();
    try {
        root = Path(tmpdir);
        scaffold_pkg(root);
        cfg = pkg_config_with_include(root);
        builder = WheelBuilder(config=cfg, project_root=root);
        assert builder.build() == builder.build();
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.build_to writes file with correct name" {
    tmpdir = tempfile.mkdtemp();
    try {
        root = Path(tmpdir);
        scaffold_pkg(root, "testpkg");
        cfg = pkg_config_with_include(root, "testpkg", "2.0.0");
        result = WheelBuilder(config=cfg, project_root=root).build_to(root / "dist");
        assert result.exists();
        assert result.name == wheel_filename(cfg);
    } finally {
        shutil.rmtree(tmpdir, ignore_errors=True);
    }
}

test "WheelBuilder.install_editable writes pth and dist-info" {
    tmpdir = tempfile.mkdtemp();
    try {
        root = Path(tmpdir);
        src = root / "src";
        src.mkdir();
        site = root / "site-packages";
        site.mkdir();
        cfg = pkg_config_with_include(root);
        pth = WheelBuilder(config=cfg, project_root=root).install_editable(src, site);
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

    cfg = JacConfig.from_toml_str("[package]\nname = \"p\"\nversion = \"1.0.0\"\n");
    raised2 = False;
    try {
        WheelBuilder(config=cfg, project_root=None).build();
    } except ValueError {
        raised2 = True;
    }
    assert raised2;
}

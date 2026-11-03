"""Tests for the package metadata behind `jac install -e`.

Covers the modules an editable install writes into site-packages with:
  metadata  — METADATA 2.4 string generation
  record    — RECORD CSV with SHA-256 fingerprints
  dist_info — WHEEL file, entry_points.txt and dist-info naming
  editable  — the .pth and dist-info tree themselves
"""

import hashlib;
import base64;
import csv;
import io;
import json;
import tempfile;
import shutil;
import from pathlib { Path }
import from jaclang.project.config { JacConfig }
import from jaclang.dist.publish.metadata {
    normalize_package_name,
    normalize_constraint,
    generate_metadata
}
import from jaclang.dist.publish.record { record_entry_from_bytes, generate_record }
import from jaclang.dist.publish.dist_info {
    generate_wheel_file,
    generate_entry_points,
    dist_info_dirname
}
import from jaclang.dist.publish.editable { install_editable }

def _as_any(v: any) -> any {
    return v;
}

def sha256_b64(data: bytes) -> str {
    b64 = _as_any(base64.urlsafe_b64encode(hashlib.sha256(data).digest()).rstrip(b"="));
    return f"sha256={b64.decode('ascii')}";
}

def pkg_config_with_include(
    pkg_dir: Path, name: str = "mypkg", version: str = "1.0.0"
) -> JacConfig {
    toml = '[project]\nname = "'
        + name
        + '"\nversion = "'
        + version
        + '"\nrequires-python = ">=3.11"\n\n[project.include]\npackages = ["'
        + name
        + '"]\n';
    cfg = JacConfig.from_toml_str(toml);
    cfg.project_root = pkg_dir;
    return cfg;
}

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
        '[project]\nname = "mypkg"\nversion = "1.2.3"\nrequires-python = ">=3.11"\nlicense = "MIT"\n\n[dependencies.pypi]\nrequests = ">=2.28.0"\nnumpy = "^1.24.0"\n\n[optional-dependencies.video]\nopencv-python-headless = ">=4.0"\n'
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
    assert lines
        == [
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

test "record_entry_from_bytes has correct sha256 and size" {
    data = b"hello jac";
    `entry = record_entry_from_bytes("pkg/main.jac", data);
    assert `entry.path == "pkg/main.jac";
    assert `entry.hash_value == sha256_b64(data);
    assert `entry.size == len(data);
    assert "=" not in `entry.hash_value[len("sha256="):];
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

test "install_editable writes pth and dist-info" {
    tmpdir = tempfile.mkdtemp();
    try {
        proj = Path(tmpdir);
        src = proj / "src";
        src.mkdir();
        site = proj / "site-packages";
        site.mkdir();
        cfg = pkg_config_with_include(proj);
        pth = install_editable(cfg, src, site);
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

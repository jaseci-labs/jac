"""Tests for the `jac eject` command.

These tests run eject in-process against tiny projects materialized in
TemporaryDirectory(), so the whole file completes in well under a
second on a warm cache and runs as part of the standard `pytest jac`
suite. The goal is to catch file-collection, codegen, and boilerplate
regressions on every push, without paying the cost of the wheel-build
/ HTTP smoke pipeline.
"""

import ast;
import io;
import json;
import sys;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.cli.commands { eject }


"""Run jac eject silencing console output. Returns the exit code."""
def _silent_eject(source: str, output: str = "", force: bool = False) -> int {
    buf = io.StringIO();
    old_out = sys.stdout;
    old_err = sys.stderr;
    sys.stdout = buf;
    sys.stderr = buf;
    try {
        rc = eject.eject(source=source, output=output, force=force);
    } finally {
        sys.stdout = old_out;
        sys.stderr = old_err;
    }
    return rc;
}


"""Write a minimal valid jac.toml at the given source root."""
def _write_jac_toml(src: Path, name: str = "test_app") {
    src.mkdir(parents=True, exist_ok=True);
    (src / "jac.toml").write_text(
        f'[project]\nname = "{name}"\nversion = "0.1.0"\nentry-point = "main.jac"\n[dependencies]\n'
    );
}


"""Write a minimal main.jac that compiles cleanly."""
def _write_main_jac(src: Path) {
    (src / "main.jac").write_text('with entry { print("hi"); }\n');
}


"""Sorted list of all .jac files (relative paths) inside a directory."""
def _list_jac_files(d: Path) -> list[str] {
    files = [
        str(p.relative_to(d))
        for p in d.rglob("*.jac")
        if p.is_file()
    ];
    files.sort();
    return files;
}


# ==================== happy path ====================
test "eject produces expected output layout" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        assert out.exists();
        assert (out / "backend" / "main.py").exists();
        assert (out / "backend" / "serve.py").exists();
        assert (out / "backend" / "requirements.txt").exists();
        assert (out / "frontend" / "package.json").exists();
        assert (out / "frontend" / "vite.config.js").exists();
        assert (out / "frontend" / "index.html").exists();
        assert (out / "run.sh").exists();
        assert (out / "README.md").exists();
    }
}


test "ejected output contains zero .jac files" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "helper.jac").write_text('def hello() -> str { return "hi"; }\n');
        (src / "helper.impl.jac").write_text('impl hello() -> str { return "hi"; }\n');
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        leftover = _list_jac_files(out);
        assert leftover == [] , f"Ejected output still has .jac files: {leftover}";
    }
}


# ==================== codegen validity ====================
test "every emitted .py file parses as valid Python" {
    # The strongest cheap correctness check we have without booting a
    # server: round-trip every emitted backend module through ast.parse
    # so codegen regressions that produce broken Python fail loudly.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "users.sv.jac").write_text('def get_user() -> str { return "alice"; }\n');
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        py_files = sorted((out / "backend").rglob("*.py"));
        assert len(py_files) >= 2 , f"Expected backend .py files, got {py_files}";
        for py in py_files {
            try {
                ast.parse(py.read_text());
            } except SyntaxError as e {
                raise AssertionError(f"Emitted invalid Python in {py.name}: {e}");
            }
        }
    }
}


test "emitted package.json is valid JSON with required keys" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 0;
        pkg_path = src.parent / "myapp-ejected" / "frontend" / "package.json";
        # json.loads raises if the file isn't valid JSON.
        pkg = json.loads(pkg_path.read_text());
        assert pkg["name"] == "myapp";
        assert "scripts" in pkg;
        assert "dev" in pkg["scripts"];
        # Vite is always added to devDependencies as a baseline so
        # `npm run dev` works out of the box.
        assert "vite" in pkg["devDependencies"];
    }
}


test "user code from main.jac survives the round-trip into main.py" {
    # Catches the "eject swallowed the function body" class of bug:
    # codegen runs, file is written, but the user's actual logic is
    # missing. A unique marker string flushed through `print(...)` is
    # the smallest signal that codegen actually ran end-to-end.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        (src / "main.jac").write_text('with entry { print("EJECT_MARKER_91A2F3"); }\n');
        rc = _silent_eject(str(src));
        assert rc == 0;
        main_py = (src.parent / "myapp-ejected" / "backend" / "main.py").read_text();
        assert "EJECT_MARKER_91A2F3" in main_py;
    }
}


# ==================== sv/cl routing ====================
test "sv files route to backend, cl files route to frontend" {
    # The whole point of eject is that .sv.jac compiles to Python in
    # backend/ and .cl.jac compiles to JavaScript in frontend/src/.
    # Verifies _to_py_rel_path / _to_js_rel_path / _is_meaningful_python
    # actually segregate output by context tag.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "users.sv.jac").write_text('def get_user() -> str { return "alice"; }\n');
        (src / "widget.cl.jac").write_text(
            'cl { def:pub w() -> any { return <div></div>; } }\n'
        );
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        # users.sv.jac must produce backend Python only.
        assert (out / "backend" / "users.py").exists();
        assert not (out / "frontend" / "src" / "users.js").exists();
        # widget.cl.jac must produce frontend JavaScript only. The
        # corresponding Python module is filtered out by
        # _is_meaningful_python (a .cl module's Python output is just
        # imports / a docstring with no behavior to ship server-side).
        assert (out / "frontend" / "src" / "widget.js").exists();
        assert not (out / "backend" / "widget.py").exists();
    }
}


# ==================== regression: .jac/ build cache ====================
test "eject succeeds when source contains a .jac build-cache directory" {
    # Regression: Path.rglob("*.jac") matches both files AND directories
    # whose name ends in .jac. Before the fix, the .jac/ build cache
    # directory itself was passed to JacProgram.compile and crashed with
    # "[Errno 21] Is a directory". Any project that had been built before
    # ejecting would fail.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        cache = src / ".jac";
        cache.mkdir();
        (cache / "cached.jac").write_text("garbage that must not be compiled {");
        (cache / "metadata.txt").write_text("cache metadata");
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        assert (out / "backend" / "main.py").exists();
    }
}


# ==================== file collection rules ====================
test "eject excludes .impl.jac and .test.jac files" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "main.impl.jac").write_text("# impl shenanigans\n");
        (src / "stuff.test.jac").write_text('test "foo" { assert True; }\n');
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        assert not (out / "backend" / "main.impl.py").exists();
        assert not (out / "backend" / "stuff.test.py").exists();
    }
}


test "eject skips build, vendor, and hidden directories" {
    # Covers both branches of the exclusion logic in _collect_jac_files:
    # the well-known _SKIP_DIRS set and the generic startswith(".") check.
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        excluded_dirs = [
            "node_modules",
            ".venv",
            "venv",
            "dist",
            "build",
            "__pycache__",
            ".hidden"
        ];
        for ex_dir in excluded_dirs {
            d = src / ex_dir;
            d.mkdir();
            (d / "junk.jac").write_text("garbage that must not compile {");
        }
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        leaked = [str(p.relative_to(out)) for p in out.rglob("junk*")];
        leaked.sort();
        assert leaked == [] , f"Excluded-dir junk leaked into output: {leaked}";
    }
}


# ==================== assets ====================
test "eject copies assets directory into frontend src" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        assets = src / "assets";
        assets.mkdir();
        (assets / "logo.txt").write_text("static asset content");
        rc = _silent_eject(str(src));
        assert rc == 0;
        out = src.parent / "myapp-ejected";
        copied = out / "frontend" / "src" / "assets" / "logo.txt";
        assert copied.exists();
        assert copied.read_text() == "static asset content";
    }
}


# ==================== output directory semantics ====================
test "eject refuses to overwrite existing output without force" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc1 = _silent_eject(str(src));
        assert rc1 == 0;
        rc2 = _silent_eject(str(src));
        assert rc2 == 1;
    }
}


test "eject force overwrites existing output directory" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc1 = _silent_eject(str(src));
        assert rc1 == 0;
        out = src.parent / "myapp-ejected";
        (out / "MARKER.txt").write_text("should be removed by force");
        rc2 = _silent_eject(str(src), force=True);
        assert rc2 == 0;
        assert not (out / "MARKER.txt").exists();
        assert (out / "backend" / "main.py").exists();
    }
}


test "eject explicit output path lands at the requested location" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        target = Path(td) / "elsewhere" / "ejected";
        rc = _silent_eject(str(src), output=str(target));
        assert rc == 0;
        assert target.exists();
        assert (target / "backend" / "main.py").exists();
        # Default sibling location must NOT have been created.
        assert not (src.parent / "myapp-ejected").exists();
    }
}


# ==================== error handling ====================
test "eject errors when jac.toml is missing" {
    with TemporaryDirectory() as td {
        src = Path(td) / "noproject";
        src.mkdir();
        _write_main_jac(src);
        rc = _silent_eject(str(src));
        assert rc == 1;
    }
}


test "eject errors when output equals source" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        rc = _silent_eject(str(src), output=str(src));
        assert rc == 1;
    }
}


test "eject errors when source contains a syntactically invalid .jac file" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        _write_jac_toml(src, "myapp");
        _write_main_jac(src);
        (src / "broken.jac").write_text("def hello -> int { return ; ");
        rc = _silent_eject(str(src));
        assert rc != 0;
    }
}


# ==================== metadata helpers ====================
test "load_eject_project_metadata falls back to source dir name on placeholder" {
    with TemporaryDirectory() as td {
        src = Path(td) / "actual_dir_name";
        src.mkdir();
        (src / "jac.toml").write_text(
            '[project]\nname = "{{name}}"\nversion = "0.1.0"\nentry-point = "main.jac"\n'
        );
        meta = eject.load_eject_project_metadata(src);
        assert meta["project_name"] == "actual_dir_name";
        assert meta["entry_point"] == "main.jac";
        assert meta["entry_module"] == "main";
    }
}


test "load_eject_project_metadata uses jac.toml name when not a placeholder" {
    with TemporaryDirectory() as td {
        src = Path(td) / "wrong_dir_name";
        src.mkdir();
        (src / "jac.toml").write_text(
            '[project]\nname = "real_name"\nversion = "0.1.0"\nentry-point = "main.jac"\n'
        );
        meta = eject.load_eject_project_metadata(src);
        assert meta["project_name"] == "real_name";
    }
}


test "load_eject_project_metadata strips sv context tag from entry_module" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        src.mkdir();
        (src / "jac.toml").write_text(
            '[project]\nname = "myapp"\nentry-point = "main.sv.jac"\n'
        );
        meta = eject.load_eject_project_metadata(src);
        assert meta["entry_module"] == "main";
    }
}


test "resolve_eject_output defaults to sibling -ejected directory" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        src.mkdir();
        out = eject.resolve_eject_output(src, "");
        assert out == (Path(td) / "myapp-ejected").resolve();
    }
}


test "resolve_eject_output honors explicit output argument" {
    with TemporaryDirectory() as td {
        src = Path(td) / "myapp";
        src.mkdir();
        explicit = Path(td) / "elsewhere";
        out = eject.resolve_eject_output(src, str(explicit));
        assert out == explicit.resolve();
    }
}

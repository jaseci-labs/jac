"""Tests for the `jac build` whole-program .jab builder."""

import os;
import json;
import struct;
import tempfile;
import shutil;
import marshal;
import jaclang;
import from pathlib { Path }
import from jaclang.cli.commands.build { build }
import from jaclang.jac0core.jir {
    parse_header,
    read_sections,
    read_program_jir,
    write_program_jir,
    FLAG_PROGRAM,
    SEC_MANIFEST,
    SEC_DEPGRAPH,
    SEC_MODULE_TABLE,
    SEC_BYTECODE,
    SECTIONS_MAGIC,
    HEADER_SIZE,
    JabKind,
    CAP_HAS_SERVER,
    CAP_HAS_ENTRY,
    CAP_ATTACHABLE,
    capabilities_for_kind
}


"""Write a two-module project (app imports helper) into tmp_path."""
def _make_project(tmp_path: str) {
    toml = (
        '[project]\n'
        'name = "buildtest"\n'
        'version = "1.0.0"\n'
        'entry-point = "app.jac"\n'
    );
    (Path(tmp_path) / "jac.toml").write_text(toml);
    (Path(tmp_path) / "helper.jac").write_text(
        'def greet(name: str) -> str {\n    return f"Hello, {name}!";\n}\n'
    );
    (Path(tmp_path) / "app.jac").write_text(
        'import from helper { greet }\n\n' 'with entry {\n    print(greet("Jac"));\n}\n'
    );
}


"""Parse a .jab and return (header, top_sections, module_list)."""
def _parse_jab(blob: bytes) -> tuple[object, dict[int, bytes], list[dict]] {
    header = parse_header(blob);
    magic = bytes(SECTIONS_MAGIC);
    pos = blob.find(magic, HEADER_SIZE);
    sections = read_sections(blob, pos + len(magic));

    table = sections[SEC_MODULE_TABLE];
    p = 0;
    (count, ) = struct.unpack_from('<I', table, p);
    p += 4;
    modules: list[dict] = [];
    for _ in range(count) {
        (plen, ) = struct.unpack_from('<I', table, p);
        p += 4;
        rel_path = table[p:p + plen].decode('utf-8');
        p += plen;
        (content_hash, ) = struct.unpack_from('<Q', table, p);
        p += 8;
        (blen, ) = struct.unpack_from('<I', table, p);
        p += 4;
        inner = table[p:p + blen];
        p += blen;
        ipos = inner.find(magic);
        inner_secs = read_sections(inner, ipos + len(magic));
        modules.append(
            {"rel_path": rel_path, "content_hash": content_hash, "sections": inner_secs}
        );
    }
    return (header, sections, modules);
}


test "build emits a FLAG_PROGRAM .jab with all closure modules" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);

        rc = build(filename="app.jac", no_typecheck=True);
        assert rc == 0;

        jab = Path(tmp_path) / ".jac" / "build" / "release" / "app.jab";
        assert jab.exists();

        blob = jab.read_bytes();
        (header, sections, modules) = _parse_jab(blob);

        # Header carries the whole-program flag.
        assert header is not None;
        assert (header.flags & FLAG_PROGRAM) != 0;

        # Both user modules travel in the bundle.
        rel_paths = `set(m["rel_path"] for m in modules);
        assert "app.jac" in rel_paths;
        assert "helper.jac" in rel_paths;

        # Each module's bytecode unmarshals back to a code object.
        for m in modules {
            bc = m["sections"].get(SEC_BYTECODE);
            assert bc is not None;
            code = marshal.loads(bc);
            assert type(code).__name__ == "code";
        }
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "build records the import dependency graph (rel paths)" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);

        rc = build(filename="app.jac", no_typecheck=True);
        assert rc == 0;

        jab = (Path(tmp_path) / ".jac" / "build" / "release" / "app.jab").read_bytes();
        (header, sections, modules) = _parse_jab(jab);

        manifest = json.loads(sections[SEC_MANIFEST].decode('utf-8'));
        assert manifest["entry"] == "app.jac";
        assert manifest["profile"] == "release";

        dep_graph = json.loads(sections[SEC_DEPGRAPH].decode('utf-8'));
        assert "app.jac" in dep_graph;
        assert "helper.jac" in dep_graph["app.jac"];
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "build --out writes to a custom path" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);

        out = str(Path(tmp_path) / "dist" / "custom.jab");
        rc = build(filename="app.jac", out=out, no_typecheck=True);
        assert rc == 0;
        assert Path(out).exists();
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "build errors when entry file does not exist" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);

        rc = build(filename="nonexistent.jac", no_typecheck=True);
        assert rc == 1;
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


"""Write a project whose entry passes the wrong types across a module boundary."""
def _make_typeerror_project(tmp_path: str) {
    toml = (
        '[project]\n'
        'name = "typeerr"\n'
        'version = "1.0.0"\n'
        'entry-point = "app.jac"\n'
    );
    (Path(tmp_path) / "jac.toml").write_text(toml);
    (Path(tmp_path) / "lib.jac").write_text(
        'def add(a: int, b: int) -> int {\n    return a + b;\n}\n'
    );
    (Path(tmp_path) / "app.jac").write_text(
        'import from lib { add }\n\n'
        'with entry {\n    x: int = add("not", "ints");\n    print(x);\n}\n'
    );
}


test "build --check-only passes for a valid project" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);

        rc = build(filename="app.jac", check_only=True);
        assert rc == 0;
        # --check-only emits nothing.
        assert not (Path(tmp_path) / ".jac" / "build").exists();
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "build gate fails on a cross-module type error and emits nothing" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_typeerror_project(tmp_path);

        rc = build(filename="app.jac");
        assert rc == 1;
        # Fail-closed: no artifact written.
        assert not (Path(tmp_path) / ".jac" / "build").exists();
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "build --no-typecheck bypasses the gate on a type error" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_typeerror_project(tmp_path);

        rc = build(filename="app.jac", no_typecheck=True);
        assert rc == 0;
        assert (Path(tmp_path) / ".jac" / "build" / "release" / "app.jab").exists();
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "build emits kind and capabilities in manifest" {
    tmp_path = tempfile.mkdtemp();
    original_cwd = os.getcwd();
    os.chdir(tmp_path);
    try {
        _make_project(tmp_path);

        rc = build(filename="app.jac", no_typecheck=True);
        assert rc == 0;

        jab = (Path(tmp_path) / ".jac" / "build" / "release" / "app.jab").read_bytes();
        (header, sections, modules) = _parse_jab(jab);

        manifest = json.loads(sections[SEC_MANIFEST].decode('utf-8'));
        # app.jac has a `with entry {}` block -> auto-detected as "script".
        assert manifest["kind"] == "script";
        # Script capabilities: CAP_HAS_SERVER | CAP_HAS_ENTRY = 0x01 | 0x08 = 9
        assert manifest["capabilities"] == (CAP_HAS_SERVER | CAP_HAS_ENTRY);
    } finally {
        os.chdir(original_cwd);
        shutil.rmtree(tmp_path, ignore_errors=True);
    }
}


test "read_program_jir round-trips a whole-program bundle" {
    # Build a minimal bundle via write_program_jir and read it back.
    import sys;
    dummy_bc = marshal.dumps(compile("x = 42", "<test>", "exec"));
    inner_secs: dict[int, bytes] = {SEC_BYTECODE: dummy_bc};
    modules = [("main.jac", 12345, inner_secs)];
    manifest: dict[str, object] = {
        "format": 1,
        "kind": "script",
        "capabilities": CAP_HAS_SERVER | CAP_HAS_ENTRY,
        "profile": "release",
        "entry": "main.jac",
        "py_tag": list(sys.version_info[:2])
    };
    dep_graph: dict[str, list[str]] = {"main.jac": []};

    blob = write_program_jir(modules, manifest, dep_graph);

    # Round-trip read.
    result = read_program_jir(blob);
    assert result is not None;
    (out_manifest, out_depgraph, out_modules) = result;

    # Manifest is preserved.
    assert out_manifest["kind"] == "script";
    assert out_manifest["capabilities"] == (CAP_HAS_SERVER | CAP_HAS_ENTRY);
    assert out_manifest["entry"] == "main.jac";

    # Dep graph is preserved.
    assert "main.jac" in out_depgraph;
    assert out_depgraph["main.jac"] == [];

    # Module table round-trips with bytecode.
    assert len(out_modules) == 1;
    (rel_path, content_hash, inner) = out_modules[0];
    assert rel_path == "main.jac";
    assert content_hash == 12345;
    assert SEC_BYTECODE in inner;
    code = marshal.loads(inner[SEC_BYTECODE]);
    assert type(code).__name__ == "code";
}


test "read_program_jir rejects non-program JIR" {
    # A minimal non-FLAG_PROGRAM blob should return None.
    result = read_program_jir(b'\x00' * 64);
    assert result is None;
}


test "capabilities_for_kind returns correct flags" {
    # Script: server + entry
    assert capabilities_for_kind(JabKind.SCRIPT) == (CAP_HAS_SERVER | CAP_HAS_ENTRY);
    # Package: server + attachable, no entry
    assert capabilities_for_kind(JabKind.PY_PACKAGE) == (CAP_HAS_SERVER | CAP_ATTACHABLE);
    # Verify the package does NOT have CAP_HAS_ENTRY.
    assert (capabilities_for_kind(JabKind.PY_PACKAGE) & CAP_HAS_ENTRY) == 0;
}

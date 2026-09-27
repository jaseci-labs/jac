"""The native interface record: what a consumer links against (#8943).

One record per native unit, digest-prefixed exactly as the type interface
is. A body edit, a renamed local or a new private helper leaves the digest
alone; an export, signature, layout, enum member or initializer change moves
it. The record round-trips through its bytes, and the merged class layout
refuses a class two units lay out differently.
"""

import os;
import shutil;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.jir {
    NativeStamp,
    SEC_NIFACE,
    native_section_payload
}
import from jaclang.compiler.driver.native_iface {
    NIFACE_HASH_LEN,
    NativeClassLayout,
    NativeExport,
    NativeFieldSlot,
    NativeIface,
    layout_digest,
    merge_class_layouts
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo {
    native_entry_name,
    native_glob_init_name,
    native_symbol_name,
    native_unit_prefix
}

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures" / "link_diamond");

def _native_opts -> CompileOptions {
    return CompileOptions(
        aot_mode=True, default_codespace='native', skip_native_engine=True
    );
}

def _iface_of(path: str) -> NativeIface {
    prog = JacProgram();
    mod = prog.compile(file_path=path, options=_native_opts());
    assert not prog.errors_had , [str(e) for e in prog.errors_had];
    assert mod.gen.native_iface is not None , f"no native interface for {path}";
    return mod.gen.native_iface;
}

"""Write `text` as `name` under `scratch` (a fresh directory when
none is given). Variants of one module must share a path: the unit prefix,
and with it every symbol and the digest, is keyed on the module's path."""
def _scratch_copy(name: str, text: str, scratch: str = "") -> str {
    tmp = scratch or tempfile.mkdtemp(prefix="jac-niface-");
    p = os.path.join(tmp, name);
    with open(p, "w", encoding="utf-8") as f {
        f.write(text);
    }
    return p;
}

test "a unit's record names its exports under the unit prefix" {
    path = os.path.join(FIXTURES, "base.jac");
    iface = _iface_of(path);
    prefix = native_unit_prefix(path);
    assert iface.prefix == prefix;
    assert iface.exports["scale"].symbol == native_symbol_name(prefix, "scale");
    assert not iface.exports["scale"].is_pub;
    assert iface.exports["diamond_abi_version"].symbol == "diamond_abi_version";
    assert iface.exports["diamond_abi_version"].is_pub;
    assert iface.exports["Point.sum"].symbol == native_symbol_name(prefix, "Point.sum");
    assert iface.init_symbol == native_glob_init_name(path);
    assert "Point" in iface.classes;
    assert "x" in iface.classes["Point"].fields;
    assert iface.pub_symbols() == ["diamond_abi_version"];
}

test "the record round-trips through its bytes with a stable digest" {
    path = os.path.join(FIXTURES, "base.jac");
    iface = _iface_of(path);
    raw = iface.to_bytes();
    assert NativeIface.read_digest(raw) == iface.digest();
    assert len(NativeIface.read_digest(raw) or "") == NIFACE_HASH_LEN;
    back = NativeIface.from_bytes(raw);
    assert back is not None;
    assert back.digest() == iface.digest();
    assert sorted(back.exports.keys()) == sorted(iface.exports.keys());
    assert back.classes["Point"].to_dict() == iface.classes["Point"].to_dict();
}

test "cached interfaces preserve nested container schemas for materialization" {
    schema: dict[str, any] = {
        "code": "dict",
        "key_offset": 16,
        "data_offset": 24,
        "order_offset": 32,
        "element": {
            "code": "list",
            "data_offset": 16,
            "element": {"code": "obj", "class": "Symbol"}
        }
    };
    slot = NativeFieldSlot.from_dict(
        {"index": 0, "offset": 8, "code": "natdict", "schema": schema}
    );
    iface = NativeIface(
        module="scope",
        classes={"Scope": NativeClassLayout(name="Scope", fields={"names": slot})}
    );
    back = NativeIface.from_bytes(iface.to_bytes());
    assert back is not None;
    assert back.digest() == iface.digest();
    layouts = merge_class_layouts([back]);
    assert layouts["Scope"]["fields"]["names"]["schema"] == schema;
    restored = back.classes["Scope"].fields["names"].schema;
    assert restored is not None;
    restored.data_offset += 8;
    assert back.digest() != iface.digest();
}

test "a body edit keeps the digest; an export change moves it" {
    src = (Path(FIXTURES) / "base.jac").read_text();
    scratch = tempfile.mkdtemp(prefix="jac-niface-");
    p_a = _scratch_copy("unit.jac", src, scratch);
    digest_a = _iface_of(p_a).digest();

    body_edit = src.replace("return v * k;", "return k * v;");
    assert body_edit != src;
    p_b = _scratch_copy("unit.jac", body_edit, scratch);
    assert _iface_of(p_b).digest() == digest_a , "a body edit must not move the digest";

    private_helper = src
        + "\ndef:priv helper_only(v: int) -> int {\n    return v;\n}\n";
    p_c = _scratch_copy("unit.jac", private_helper, scratch);
    assert _iface_of(p_c).digest() == digest_a , "a private helper must not move the digest";

    new_export = src + "\ndef another(v: int) -> int {\n    return v;\n}\n";
    p_d = _scratch_copy("unit.jac", new_export, scratch);
    assert _iface_of(p_d).digest() != digest_a , "a new export must move the digest";

    new_field = src.replace("y: int = 0;", "y: int = 0,\n        z: int = 0;");
    p_e = _scratch_copy("unit.jac", new_field, scratch);
    assert _iface_of(p_e).digest() != digest_a , "a layout change must move the digest";
}

test "the section in the module JIR carries the stamp of its compile" {
    import from jaclang.compiler.driver.jir { read_section_bytes }
    path = os.path.join(FIXTURES, "base.jac");
    prog = JacProgram();
    opts = _native_opts();
    mod = prog.compile(file_path=path, options=opts);
    assert mod.gen.native_iface is not None;
    import from jaclang.compiler.driver.ifacecache { artifact_cache_path }
    data = artifact_cache_path(path, prog).read_bytes();
    raw = read_section_bytes(data, SEC_NIFACE);
    assert raw is not None , "the native interface must be in the module JIR";
    stamp = prog.native_units().stamp_for(prog.options, path);
    payload = native_section_payload(raw, stamp);
    assert payload is not None;
    assert stamp.codegen_identity == prog.options.unit_codegen_identity(path);
    assert NativeIface.read_digest(payload) == mod.gen.native_iface.digest();
    other = NativeStamp(compiler_digest="x", codegen_identity="y", triple="z");
    assert native_section_payload(raw, other) is None , "a foreign stamp reads as absent";
}

test "merged layouts refuse a class two units lay out differently" {
    a = NativeIface(module="a", prefix="a");
    b = NativeIface(module="b", prefix="b");
    slot = NativeFieldSlot(index=0, offset=0, code="int");
    a.classes["P"] = NativeClassLayout(name="P", size=8, fields={"x": slot});
    b.classes["P"] = NativeClassLayout(name="P", size=8, fields={"x": slot});
    merged = merge_class_layouts([a, b]);
    assert set(merged.keys()) == {"P"};
    assert layout_digest(merged) == layout_digest(merge_class_layouts([b, a]));
    b.classes["P"] = NativeClassLayout(name="P", size=16, fields={"x": slot});
    raised = False;
    try {
        merge_class_layouts([a, b]);
    } except ValueError {
        raised = True;
    }
    assert raised , "a size disagreement must be refused";
}

test "default argument changes move the native interface" {
    scratch = tempfile.mkdtemp(prefix="jac-default-iface-");
    path = _scratch_copy("base.jac", "def f(x: int = 1) -> int { return x; }", scratch);
    before = _iface_of(path);
    Path(path).write_text("def f(x: int = 2) -> int { return x; }");
    after = _iface_of(path);
    assert before.exports["f"].param_defaults != after.exports["f"].param_defaults;
    assert before.digest() != after.digest();
    restored = NativeIface.from_bytes(after.to_bytes());
    assert restored is not None;
    assert restored.exports["f"].param_defaults == after.exports["f"].param_defaults;
}

test "native source revisions include deletion, preserved timestamps and annex membership" {
    import from jaclang.compiler.driver.nativecache { NativeUnitRegistry }
    scratch = tempfile.mkdtemp(prefix="jac-native-revision-");
    path = Path(_scratch_copy("base.jac", "def f -> int { return 1; }", scratch));
    registry = NativeUnitRegistry(JacProgram());
    ent = registry.record(str(path), NativeIface());
    old_stat = path.stat();
    path.write_text("def f -> int { return 2; }");
    os.utime(path, ns=(old_stat.st_atime_ns, old_stat.st_mtime_ns));
    assert not registry._entry_fresh(ent);
    ent = registry.record(str(path), NativeIface());
    annex = Path(scratch) / "base.impl.jac";
    annex.write_text("impl f -> int { return 2; }");
    assert not registry._entry_fresh(ent);
    ent = registry.record(str(path), NativeIface());
    annex.unlink();
    assert not registry._entry_fresh(ent);
    ent = registry.record(str(path), NativeIface());
    path.unlink();
    assert not registry._entry_fresh(ent);
}

test "native products and relocatable paths coexist in one JIR" {
    import from jaclang.compiler.driver.jir {
        JirPaths,
        SEC_PATH_ROOT,
        SEC_NBITCODE,
        SEC_NOBJ,
        SEC_NDEPS,
        SEC_NCTDEPS,
        read_jir_paths,
        read_section_bytes,
        write_precompiled_jir
    }
    import from jaclang.jac0core.sealed { JIR_FORMAT_VERSION }
    import from jaclang.compiler.driver.jir { FORMAT_VERSION }
    assert JIR_FORMAT_VERSION == FORMAT_VERSION;
    sections = [
        SEC_NIFACE,
        SEC_NBITCODE,
        SEC_NOBJ,
        SEC_NDEPS,
        SEC_NCTDEPS,
        SEC_PATH_ROOT
    ];
    assert len(set(sections)) == len(sections);
    stamp = NativeStamp(
        compiler_digest="compiler", codegen_identity="options", triple="target"
    );
    iface = NativeIface(module="example", prefix="example");
    data = write_precompiled_jir(
        None,
        extra_sections={
            SEC_NIFACE: stamp.pack(iface.to_bytes()),
            SEC_PATH_ROOT: JirPaths(base_dir="/build/package").to_bytes()
        }
    );
    payload = native_section_payload(read_section_bytes(data, SEC_NIFACE), stamp);
    assert payload is not None;
    decoded = NativeIface.from_bytes(payload);
    assert decoded is not None and decoded.digest() == iface.digest();
    paths = read_jir_paths(data, "/installed/package");
    assert paths.resolve("/build/package/dependency.jac")
        == "/installed/package/dependency.jac";
}

test "a unit's layout keeps a function named like a dependency's foreign symbol" {
    scratch = tempfile.mkdtemp(prefix="jac-niface-foreign-");
    _scratch_copy(
        "helper.jac",
        "import from m { def sqrt(x: f64) -> f64; }\n"
            + "def:pub m_sqrt(x: float) -> float {\n    return sqrt(f64(x));\n}\n",
        scratch
    );
    lib_path = _scratch_copy(
        "lib.jac",
        "import from helper { m_sqrt }\n"
            + "def sqrt(x: float) -> float {\n    return m_sqrt(x);\n}\n",
        scratch
    );
    iface = _iface_of(lib_path);
    assert "sqrt" in iface.clib_symbol_lib , sorted(iface.clib_symbol_lib.keys());
    assert "sqrt" in iface.exports , sorted(iface.exports.keys());
    assert iface.layout is not None;
    assert "sqrt" in iface.layout.functions , sorted(iface.layout.functions.keys());
}

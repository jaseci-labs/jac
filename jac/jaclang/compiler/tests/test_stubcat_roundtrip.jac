"""Stub catalog round trip.

Builds a small catalog (the prelude closure plus `math`) from the vendored
sources, opens it with the reader, and checks that what comes back is the
evaluator's own object model: a merged builtins scope, class records with
their MRO and members, function records with their signatures, and a clean
catalog-backed check of a program that leans on all of them.

Skips when the vendored typeshed sources are not in this checkout (the
writer needs them; a bundled binary would carry the catalog instead).
"""
import os;
import tempfile;
import from jaclang.compiler.types.stubcat.build { build_catalog }
import from jaclang.compiler.types.stubcat.locate {
    ENV_FILE,
    jaclang_pkg_dir,
    reset_catalog_cache,
    typeshed_stdlib_dir
}
import from jaclang.compiler.types.stubcat.reader { StubCatalog, open_catalog_file }
import from jaclang.compiler.types.types { ClassType, FunctionType, OverloadedType }

glob SMALL_SET: list[str] = [
         "builtins",
         "typing",
         "typing_extensions",
         "types",
         "enum",
         "abc",
         "sys",
         "math",
         "_typeshed",
         "_collections_abc",
         "collections",
         "collections.abc",
         "jac_builtins",
         "builtin_overrides",
         "dom_types",
         "na_builtins",
         "js_globals",
         "typing_ambient"
     ],
     _built: list = [];

def sources_present -> bool {
    return os.path.isfile(
        os.path.join(typeshed_stdlib_dir(jaclang_pkg_dir()), "builtins.pyi")
    );
}

def small_catalog -> tuple[StubCatalog, str] {
    if _built {
        return (_built[0], _built[1]);
    }
    out = os.path.join(tempfile.mkdtemp(prefix="stubcat-"), "stubcat.bin");
    manifest = build_catalog(out, only=SMALL_SET, quiet=True);
    assert manifest["modules"] >= len(SMALL_SET) - 2 , manifest;
    cat = open_catalog_file(out, jaclang_pkg_dir());
    assert cat is not None;
    _built.append(cat);
    _built.append(out);
    return (cat, out);
}

test "the builtins record is the merged prelude scope" {
    if not sources_present() {
        return;
    }
    (cat, out) = small_catalog();
    builtins = cat.module("builtins");
    assert builtins is not None;
    names = builtins.names_in_scope;
    for expected in (
        "int",
        "str",
        "list",
        "dict",
        "object",
        "Root",
        "Node",
        "Walker"
    ) {
        assert expected in names , f"builtins is missing {expected}";
    }
    root_sym = names["Root"];
    assert root_sym.provider is not None;
    assert root_sym.in_stub_scope();
}

test "class records carry mro, members and identity" {
    if not sources_present() {
        return;
    }
    (cat, out) = small_catalog();
    builtins = cat.module("builtins");
    str_sym = builtins.names_in_scope["str"];
    str_type = str_sym.provider.resolve_type(str_sym);
    assert isinstance(str_type, ClassType) , str_type;
    assert str_type.shared.class_name == "str";
    assert str_type.shared.is_builtin_class;
    mro_names = [c.shared.class_name for c in str_type.shared.mro];
    assert "object" in mro_names , mro_names;
    members = str_type.shared.symbol_table.names_in_scope;
    assert "upper" in members and "join" in members , sorted(members.keys())[:20];
    key = str_type.shared.canonical_key();
    assert key is not None
        and key[3] == "str"
        and key[0].endswith("builtins.pyi") , key;
    upper_type = members["upper"].provider.resolve_type(members["upper"]);
    assert isinstance(upper_type, (FunctionType, OverloadedType)) , upper_type;
}

test "function records keep their signatures" {
    if not sources_present() {
        return;
    }
    (cat, out) = small_catalog();
    math_mod = cat.module("math");
    assert math_mod is not None;
    sqrt_sym = math_mod.names_in_scope["sqrt"];
    sqrt_type = sqrt_sym.provider.resolve_type(sqrt_sym);
    assert isinstance(sqrt_type, FunctionType) , sqrt_type;
    ret = sqrt_type.return_type;
    assert isinstance(ret, ClassType) and ret.shared.class_name == "float" , ret;
    assert len(sqrt_type.parameters) == 1 , sqrt_type.parameters;
}

test "a catalog-backed check of a small program is clean" {
    if not sources_present() {
        return;
    }
    (cat, out) = small_catalog();
    import from jaclang.compiler.driver.program { JacProgram }
    import from jaclang.compiler.driver.compile_options { CompileOptions }
    previous = os.environ.get(ENV_FILE);
    os.environ[ENV_FILE] = out;
    reset_catalog_cache();
    try {
        prog = JacProgram();
        assert prog._get_compiler().ensure_stub_catalog() is not None;
        src = "import math;\n"
        "\n"
        "obj Point {\n"
        "    has x: float = 0.0,\n"
        "        y: float = 0.0;\n"
        "\n"
        "    def norm -> float {\n"
        "        return math.sqrt(self.x * self.x + self.y * self.y);\n"
        "    }\n"
        "}\n"
        "\n"
        "def labels(points: list[Point]) -> dict[str, float] {\n"
        "    out: dict[str, float] = {};\n"
        "    for (i, p) in enumerate(points) {\n"
        "        out[str(i).upper()] = p.norm();\n"
        "    }\n"
        "    return out;\n"
        "}\n";
        prog.compile(
            file_path="stubcat_probe.jac",
            use_str=src,
            options=CompileOptions(no_cgen=True)
        );
        errors = [str(e) for e in prog.errors_had];
        assert errors == [] , errors;
    } finally {
        if previous is None {
            os.environ.pop(ENV_FILE, None);
        } else {
            os.environ[ENV_FILE] = previous;
        }
        reset_catalog_cache();
    }
}

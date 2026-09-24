"""Same-named archetypes in two modules lower natively, each as its own type.

Two modules may each define `node Passage` (or an edge, obj or walker of the
same name) -- legal Jac, and each module uses only its own. The native backend
registered archetype structs in one namespace keyed by bare name, so the
importer of both warned `native struct name collision`, kept the first layout,
and then lowered the other module's constructors, field accesses, OSP kernel
descriptors and walker dispatch against it: an ICE (`cannot store i64 to
%"List.i64"**`), a fallback to the server codespace, or, when the layouts
happened to fit, a silent miscompile. Method symbols (`Info.total`), vtables,
runtime class names and OSP type tags collided the same way.

Every archetype's native identity is now its name scoped by the defining
module (`codeinfo.native_arch_name`), computed the same way by the defining
module and by every importer, and every reference resolves through the
declaration it names.
"""

import ctypes;
import os;
import subprocess;
import tempfile;
import from tests.support {
    TESTS_DIR,
    compile_native,
    compile_native_ir,
    get_func,
    jac_command,
    native_build,
    native_run
}
import from jaclang.compiler.frontend.codeinfo {
    native_arch_display,
    native_arch_name,
    native_symbol_name,
    native_unit_prefix
}

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     ROUTES = os.path.join(FIXTURES, "scoped_arch_routes.jac"),
     ROOMS = os.path.join(FIXTURES, "scoped_arch_rooms.jac"),
     MAIN = os.path.join(FIXTURES, "scoped_arch_main.jac"),
     SHARED_NAMES = ["Passage", "Holds", "Info", "Tally"],
     EXPECTED = [
         "route_sum 7028",
         "rooms_desc east:2.5:2,west:1.25:0,n,s,2.0",
         "route_tally 7212",
         "rooms_tally ['east', 'west']/3.75",
         "survey 7 ['Passage', 'Passage'] 2 ['east', 'west']",
         "filters 220",
         "instances 5120",
         "names Passage Info",
         "infos 21.0",
         "edges [3, 4] ['n', 's']"
     ];

"""The fixture's own output lines (drops toolchain status lines)."""
def program_lines(text: str) -> list[str] {
    heads = {line.split(" ", 1)[0] for line in EXPECTED};
    return [
        line
        for line in text.split("\n")
        if line.split(" ", 1)[0] in heads
    ];
}

test "same-named archetypes get distinct module-scoped native names" {
    for name in SHARED_NAMES {
        routes = native_arch_name(ROUTES, name);
        rooms = native_arch_name(ROOMS, name);
        assert routes != rooms , f"{name} is one native type in both modules";
        assert native_arch_display(routes) == name;
        assert native_arch_display(rooms) == name;
        assert native_arch_name(os.path.relpath(ROUTES), name) == routes , (
            "the name must depend on the module file, not on how it was reached"
        );
    }
    import jaclang;
    kernel = os.path.join(
        os.path.dirname(jaclang.__file__), "runtime", "osp_kernel.jac"
    );
    assert native_arch_name(kernel, "Slot") == "Slot" , (
        "toolchain archetypes keep the bare names the backend addresses them by"
    );
}

test "each module keeps its own layout, dispatch and identity under the JIT" {
    (eng, _) = compile_native("scoped_arch_main.jac");
    assert get_func(eng, "own_route_sum", ctypes.c_int64)() == 7028;
    assert get_func(eng, "own_route_tally", ctypes.c_int64)() == 7212;
    assert get_func(eng, "aliased_tallies", ctypes.c_int64)() == 721215 , (
        "a walker spawned through an import alias ran the other module's walker"
    );
    assert get_func(eng, "survey_both", ctypes.c_int64)() == 724 , (
        "`with RoutePassage entry` / `with RoomPassage entry` dispatched to the wrong type"
    );
    assert get_func(eng, "filters", ctypes.c_int64)() == 220 , (
        "`[?:T]` / `->:E:->` matched the same-named type of the other module"
    );
    assert get_func(eng, "instance_checks", ctypes.c_int64)() == 5120 , (
        "isinstance confused the two same-named node types"
    );
    assert get_func(eng, "infos", ctypes.c_double)() == 21.0 , (
        "the same-named `Info.total` methods resolved to one body"
    );
}

test "the defining modules and the importer agree on symbols compiled apart" {
    main_ir = str(compile_native_ir("scoped_arch_main.jac").gen.llvm_ir);
    symbols: list[str] = [];
    for (fixture, path) in [
        ("scoped_arch_routes.jac", ROUTES),
        ("scoped_arch_rooms.jac", ROOMS)
    ] {
        own_ir = str(compile_native_ir(fixture).gen.llvm_ir);
        info = native_arch_name(path, "Info");
        passage = native_arch_name(path, "Passage");
        symbol = f'@"{native_symbol_name(native_unit_prefix(path), "Info.total")}"(';
        symbols.append(symbol);
        assert f"{info}.total" not in own_ir , (
            "a method symbol carries the unit prefix; the archetype scope is redundant there"
        );
        assert any(
            line.startswith("define") and symbol in line for line in own_ir.split("\n")
        ) , f"{fixture} does not define {symbol}";
        assert any(
            line.startswith("declare") and symbol in line
            for line in main_ir.split("\n")
        ) , f"the importer does not declare {symbol}";
        assert f'%"{passage}" = type' in own_ir;
        assert f'%"{passage}" = type' in main_ir , (
            f"the importer lost {fixture}'s Passage layout"
        );
    }
    assert '%"Passage" = type' not in main_ir , "a bare, shared Passage struct remains";
    assert symbols[0] != symbols[1] , "the two `Info.total` methods share one symbol";
}

test "a module's archetype identity survives its package moving" {
    with tempfile.TemporaryDirectory() as tmp {
        names: list[str] = [];
        for stage in ("first", "second-longer-path") {
            package = os.path.join(tmp, stage, "library");
            os.makedirs(package);
            with open(os.path.join(package, "jac.toml"), "w") as f {
                f.write('[project]\nname = "library"\n');
            }
            model = os.path.join(package, "model.jac");
            with open(model, "w") as f {
                f.write("obj Box { has value: int; }\n");
            }
            names.append(native_arch_name(model, "Box"));
        }
        assert names[0] == names[1] , (
            f"relocating a package changed its archetypes' native identity: {names}"
        );
        assert names[0] != "Box";
    }
}

test "unit records name archetypes by source; the link keys a shared name by identity" {
    import from jaclang.compiler.driver.native_iface { merge_class_layouts }
    routes = compile_native_ir("scoped_arch_routes.jac").gen.native_iface;
    rooms = compile_native_ir("scoped_arch_rooms.jac").gen.native_iface;
    assert routes is not None and rooms is not None;
    for (iface, path) in [(routes, ROUTES), (rooms, ROOMS)] {
        prefix = native_unit_prefix(path);
        assert iface.exports["Info.total"].symbol
            == native_symbol_name(prefix, "Info.total");
        assert "Passage" in iface.classes , sorted(iface.classes.keys());
        assert iface.classes["Passage"].name == native_arch_name(path, "Passage");
    }
    merged = merge_class_layouts([routes, rooms]);
    assert "Passage" not in merged , "two modules' Passage classes merged as one";
    assert native_arch_name(ROUTES, "Passage") in merged;
    assert native_arch_name(ROOMS, "Passage") in merged;
    assert merged[native_arch_name(ROUTES, "Passage")]["fields"].keys()
        != merged[native_arch_name(ROOMS, "Passage")]["fields"].keys();
}

test "jac run lowers the importer natively with no collision or fallback" {
    proc = subprocess.run(
        jac_command("run", MAIN), capture_output=True, text=True, timeout=900
    );
    combined = (proc.stdout or "") + (proc.stderr or "");
    assert proc.returncode == 0 , f"jac run failed: {combined[-1200:]}";
    assert "native struct name collision" not in combined , combined[-1200:];
    assert "did not lower" not in combined and "fell back" not in combined , (
        f"a module left the native codespace: {combined[-1200:]}"
    );
    assert program_lines(proc.stdout) == EXPECTED , proc.stdout;
}

test "an AOT binary built from the importer prints the same" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "scoped_arch");
        build_log = native_build(MAIN, out_bin);
        assert "native struct name collision" not in build_log , build_log[-1200:];
        assert program_lines(native_run(out_bin)) == EXPECTED;
    }
}

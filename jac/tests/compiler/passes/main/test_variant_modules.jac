"""Variant module tests — verifies that .sv.jac, .cl.jac, .na.jac files (and the
annexes that belong to them) are discovered and merged into the head module as a
single unified tree, each statement keeping its own deployment context.

Scenario 1 (variant_module/):
  mymod.jac                head with Circle {area}
  mymod.sv.jac             server variant with CircleService {describe}
  mymod.cl.jac             client variant with Display {render}
  mymod.impl.jac           head impl for Circle.area AND Display.render (cross-variant)
  impl/mymod.sv.impl.jac   server impl in shared folder
  mymod.test.jac           head test

Scenario 2 (variant_no_head/):
  svc.sv.jac               head (no plain .jac) with Handler {tag}
  svc.cl.jac               client variant with Widget {render}
  impl/svc.sv.impl.jac     head impl in shared folder
  svc.cl.impl.jac          client impl in same dir
"""

import os;
import from pathlib { Path }
import jaclang;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.bccache { discover_variant_files }
import from jaclang.jac0core.constant { CodeContext }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     VARIANT_DIR = os.path.join(FIXTURES, "variant_module"),
     NO_HEAD_DIR = os.path.join(FIXTURES, "variant_no_head");

"""Find a merged Archetype by name in the unified tree (or None)."""
def _arch(state: uni.Module, name: str) -> (uni.Archetype | None) {
    for a in state.get_all_sub_nodes(uni.Archetype) {
        if a.name.value == name {
            return a;
        }
    }
    return None;
}

"""Find a merged ImplDef by its `impl.<...>` symbol name (or None)."""
def _impl(state: uni.Module, sym_name: str) -> (uni.ImplDef | None) {
    for i in state.get_all_sub_nodes(uni.ImplDef) {
        if i.sym_name == sym_name {
            return i;
        }
    }
    return None;
}

"""Basenames of files whose statements were spliced into the head's body."""
def _origins(state: uni.Module) -> set[str] {
    return {
        os.path.basename(st.loc.mod_path)
        for st in state.body
        if st.loc.mod_path
    };
}

test "variant module complete scenario" {
    head_path = os.path.join(VARIANT_DIR, "mymod.jac");

    # --- 1. Discovery: head finds both variants ---
    variants = discover_variant_files(head_path);
    variant_names = [os.path.basename(v) for v in variants];
    assert "mymod.sv.jac" in variant_names , f"Missing mymod.sv.jac in {variant_names}";
    assert "mymod.cl.jac" in variant_names , f"Missing mymod.cl.jac in {variant_names}";

    # Variant files return empty when higher-precedence head exists
    assert discover_variant_files(os.path.join(VARIANT_DIR, "mymod.sv.jac")) == [];
    assert discover_variant_files(os.path.join(VARIANT_DIR, "mymod.cl.jac")) == [];

    # --- 2. Compile and verify no errors ---
    prog = JacProgram();
    state = prog.compile(head_path);
    assert not prog.errors_had , f"Compilation errors: {[
        e.pretty_print() for e in prog.errors_had
    ]}";

    # --- 3. Variants and annexes are merged into the head — one hub entry ---
    assert list(prog.mod.hub.keys()) == [head_path] , (
        f"Variants should be merged, not separate hub entries; got {list(
            prog.mod.hub.keys()
        )}"
    );
    origins = _origins(state);
    for f in (
        "mymod.sv.jac",
        "mymod.cl.jac",
        "mymod.impl.jac",
        "mymod.sv.impl.jac",
        "mymod.test.jac"
    ) {
        assert f in origins , f"Expected {f} to be spliced into head, got {origins}";
    }

    # --- 4. Every variant's declarations live in the head's symbol table ---
    assert state.sym_tab.lookup("Circle") is not None;
    assert state.sym_tab.lookup("CircleService") is not None;
    assert state.sym_tab.lookup("Display") is not None;

    # --- 5. Server variant declarations carry SERVER context ---
    circle_service = _arch(state, "CircleService");
    assert circle_service is not None;
    assert circle_service.code_context == CodeContext.SERVER , (
        f"Server variant should be SERVER, got {circle_service.code_context}"
    );

    # --- 6. Client variant declarations carry CLIENT context ---
    display = _arch(state, "Display");
    assert display is not None;
    assert display.code_context == CodeContext.CLIENT , (
        f"Client variant should be CLIENT, got {display.code_context}"
    );

    # --- 7. Head impl provides Circle.area (head decl) and is connected ---
    area = _impl(state, "impl.Circle.area");
    assert area is not None , "impl.Circle.area should be merged in";
    assert area.loc.mod_path.endswith("mymod.impl.jac");
    assert area.decl_link is not None , (
        "Circle.area impl should be connected to its declaration in the head"
    );

    # --- 8. Head impl ALSO provides Display.render (cross-variant to cl) ---
    render = _impl(state, "impl.Display.render");
    assert render is not None , "impl.Display.render should be merged in";
    assert render.loc.mod_path.endswith("mymod.impl.jac");
    assert render.decl_link is not None , (
        "Display.render impl should be connected to its declaration via "
        "cross-variant matching"
    );

    # --- 9. Server variant impl from shared impl/ folder is connected ---
    describe = _impl(state, "impl.CircleService.describe");
    assert describe is not None , (
        "impl.CircleService.describe should be found from shared impl/ folder"
    );
    assert describe.loc.mod_path.endswith("mymod.sv.impl.jac");
    assert describe.decl_link is not None , (
        "CircleService.describe impl should be connected to its declaration"
    );
}

test "variant precedence fallback — sv.jac as head when no plain .jac" {
    sv_path = os.path.join(NO_HEAD_DIR, "svc.sv.jac");
    cl_path = os.path.join(NO_HEAD_DIR, "svc.cl.jac");

    # --- 1. sv.jac discovers cl.jac as variant ---
    variants = discover_variant_files(sv_path);
    assert len(variants) == 1;
    assert variants[0].endswith("svc.cl.jac");

    # cl.jac returns empty (higher-precedence sv.jac exists)
    assert discover_variant_files(cl_path) == [];

    # --- 2. Compile sv.jac as head ---
    prog = JacProgram();
    state = prog.compile(sv_path);
    assert not prog.errors_had , f"Compilation errors: {[
        e.pretty_print() for e in prog.errors_had
    ]}";

    # --- 3. Merged into a single hub entry ---
    assert list(prog.mod.hub.keys()) == [sv_path];
    origins = _origins(state);
    for f in ("svc.cl.jac", "svc.sv.impl.jac", "svc.cl.impl.jac") {
        assert f in origins , f"Expected {f} merged into head, got {origins}";
    }

    # --- 4. Head (sv) decls are SERVER, client variant decls are CLIENT ---
    handler = _arch(state, "Handler");
    assert handler is not None and handler.code_context == CodeContext.SERVER;
    widget = _arch(state, "Widget");
    assert widget is not None and widget.code_context == CodeContext.CLIENT;

    # --- 5. Impl matching works across all locations ---
    tag = _impl(state, "impl.Handler.tag");
    assert tag is not None and tag.decl_link is not None , (
        "impl.Handler.tag should match from shared impl/ folder"
    );
    assert tag.loc.mod_path.endswith("svc.sv.impl.jac");

    render = _impl(state, "impl.Widget.render");
    assert render is not None and render.decl_link is not None , (
        "impl.Widget.render should match from same dir"
    );
    assert render.loc.mod_path.endswith("svc.cl.impl.jac");
    # The client impl is coerced to CLIENT context.
    assert render.code_context == CodeContext.CLIENT;
}

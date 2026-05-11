"""Variant module tests — verifies that .sv.jac, .cl.jac, .na.jac files are
discovered, loaded, and merged into the head module as variant annexes.

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
import from jaclang.jac0core.bccache { discover_variant_files, discover_annex_files }
import from jaclang.jac0core.constant { CodeContext }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "main", "fixtures"
     ),
     VARIANT_DIR = os.path.join(FIXTURES, "variant_module"),
     NO_HEAD_DIR = os.path.join(FIXTURES, "variant_no_head");

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

    # --- 3. Two variants attached ---
    assert len(state.variant_mod) == 2 , (
        f"Expected 2 variant_mod, got {len(state.variant_mod)}"
    );
    v_names = [m.name for m in state.variant_mod];
    assert "mymod.sv" in v_names , f"Missing mymod.sv variant, got {v_names}";
    assert "mymod.cl" in v_names , f"Missing mymod.cl variant, got {v_names}";

    sv_variant = [
        m
        for m in state.variant_mod
        if m.name == "mymod.sv"
    ][0];
    cl_variant = [
        m
        for m in state.variant_mod
        if m.name == "mymod.cl"
    ][0];

    # --- 4. Server variant body has SERVER context ---
    for elem in sv_variant.body {
        if isinstance(elem, uni.ContextAwareNode) {
            assert elem.code_context == CodeContext.SERVER , (
                f"Server variant should be SERVER, got {elem.code_context}"
            );
        }
    }

    # --- 5. Client variant body has CLIENT context ---
    for elem in cl_variant.body {
        if isinstance(elem, uni.ContextAwareNode) {
            assert elem.code_context == CodeContext.CLIENT , (
                f"Client variant should be CLIENT, got {elem.code_context}"
            );
        }
    }

    # --- 6. Server impl discovered from shared impl/ folder ---
    assert len(sv_variant.impl_mod) >= 1 , (
        f"Expected >=1 server variant impl, got {len(sv_variant.impl_mod)}"
    );
    sv_impl = sv_variant.impl_mod[0];
    assert sv_impl.name == "mymod.sv.impl" , f"Expected mymod.sv.impl, got {sv_impl.name}";
    describe_sym = sv_impl.sym_tab.lookup("impl.CircleService.describe");
    assert describe_sym is not None , (
        "impl.CircleService.describe should be found from shared impl/ folder"
    );
    describe_node = describe_sym.decl.name_of;
    assert isinstance(describe_node, uni.ImplDef)
    and describe_node.decl_link is not None , (
        "CircleService.describe impl should be connected to its declaration"
    );

    # --- 7. Head impl file provides Circle.area (head decl) ---
    impl_mod = [
        m
        for m in state.impl_mod
        if m.name == "mymod.impl"
    ][0];
    area_sym = impl_mod.sym_tab.lookup("impl.Circle.area");
    assert area_sym is not None , "impl.Circle.area should be in head impl";
    area_node = area_sym.decl.name_of;
    assert isinstance(area_node, uni.ImplDef) , "Should be an ImplDef";
    assert area_node.decl_link is not None , (
        "Circle.area impl should be connected to its declaration in the head module"
    );

    # --- 8. Head impl file ALSO provides Display.render (cross-variant to cl) ---
    render_sym = impl_mod.sym_tab.lookup("impl.Display.render");
    assert render_sym is not None , "impl.Display.render should be in head impl";
    render_node = render_sym.decl.name_of;
    assert isinstance(render_node, uni.ImplDef) , "Should be an ImplDef";
    assert render_node.decl_link is not None , (
        "Display.render impl should be connected to its declaration via cross-variant matching"
    );

    # --- 9. All sym tables populated correctly ---
    assert state.sym_tab.lookup("Circle") is not None;
    assert sv_variant.sym_tab.lookup("CircleService") is not None;
    assert cl_variant.sym_tab.lookup("Display") is not None;

    # --- 10. All modules in the hub ---
    hub_paths = list(prog.mod.hub.keys());
    assert any(p.endswith("mymod.jac") for p in hub_paths);
    assert any(p.endswith("mymod.sv.jac") for p in hub_paths);
    assert any(p.endswith("mymod.cl.jac") for p in hub_paths);
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

    # --- 3. Head impl found from shared impl/ folder ---
    impl_names = [m.name for m in state.impl_mod];
    assert "svc.sv.impl" in impl_names , (
        f"Expected svc.sv.impl from impl/ folder, got {impl_names}"
    );

    # --- 4. Client variant attached ---
    assert len(state.variant_mod) == 1;
    cl_variant = state.variant_mod[0];
    assert cl_variant.name == "svc.cl";

    # --- 5. Client variant has CLIENT context ---
    for elem in cl_variant.body {
        if isinstance(elem, uni.ContextAwareNode) {
            assert elem.code_context == CodeContext.CLIENT;
        }
    }

    # --- 6. Client impl from same dir ---
    v_impl_names = [m.name for m in cl_variant.impl_mod];
    assert "svc.cl.impl" in v_impl_names , (
        f"Expected svc.cl.impl, got {v_impl_names}"
    );

    # --- 7. Head body has SERVER context ---
    for elem in state.body {
        if isinstance(elem, uni.ContextAwareNode) {
            assert elem.code_context == CodeContext.SERVER;
        }
    }

    # --- 8. Impl matching works across all locations ---
    tag_sym = state.impl_mod[0].sym_tab.lookup("impl.Handler.tag");
    assert tag_sym is not None , "impl.Handler.tag should match from impl/ folder";

    render_sym = cl_variant.impl_mod[0].sym_tab.lookup("impl.Widget.render");
    assert render_sym is not None , "impl.Widget.render should match from same dir";
}

"""A C function defined in Jac stays visible in a whole-program shared object.

JacPython's object is internalized down to the plan's public exports before
the interpreter links against it, so a C definition such as Py_BytesMain has
to be one of those exports under its C name, or main cannot find it."""

import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.backends.native.link_glue { init_object_codegen }
import from jaclang.compiler.backends.native.link_plan {
    ArtifactKind,
    build_link_plan,
    internalize_native_implementation,
    whole_program_module,
    _platform_of
}
import from jaclang.compiler.backends.native.llvm.binding.value { Linkage }
import from pathlib { Path }
import from tests.support { NATIVE_FIXTURES }

test "a C definition is a public export that internalizing keeps external" {
    options = CompileOptions(
        aot_mode=True,
        default_codespace="native",
        skip_native_engine=True,
        native_required=True,
        memory_profile="rc",
        no_ir_cache=True
    );
    program = JacProgram();
    plan = build_link_plan(
        program, [str(Path(NATIVE_FIXTURES) / "shared_c_export.jac")], options
    );
    assert not program.errors_had , [e.pretty_print() for e in program.errors_had];
    assert "jac_c_export_answer" in plan.pub_exports();
    init_object_codegen();
    spec = plan.glue_spec(ArtifactKind.SHARED, _platform_of(plan.triple), False);
    (compiled, runtime_exports) = whole_program_module(plan, spec);
    internalize_native_implementation(
        compiled, plan.pub_exports() + runtime_exports + ["__jac_shared_init"]
    );
    found = [
        fn
        for fn in compiled.functions
        if fn.name == "jac_c_export_answer" and not fn.is_declaration
    ];
    assert len(found) == 1;
    assert found[0].linkage != Linkage.internal;
    helpers = [
        fn
        for fn in compiled.functions
        if fn.name.endswith(".export_helper") and not fn.is_declaration
    ];
    assert all(fn.linkage == Linkage.internal for fn in helpers);
    compiled.verify();
}

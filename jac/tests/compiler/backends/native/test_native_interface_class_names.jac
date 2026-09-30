"""A class a dependency's cached interface describes keeps its native name.

Archetypes are named natively by their declaring module
(`layout_pass.archetype_native_name`), and the importer registers each
imported archetype's struct under that name from the dependency's source.
A type can also reach the importer through the dependency's cached
interface: its ClassType then carries a catalog scope instead of the
Archetype node, and `class_type_native_name` fell back to the bare class
name. The two disagreed, so a glob typed from such a class found no struct
(`Native lowering failed for attribute access`). The payload seal hit it on
`cef_smoke.jac`, whose `browser` glob is typed from cef.jac's interface once
another unit has cached it. An interface-described class now resolves to
the name its declaration was given, through the class identity both carry.
"""

import os;
import tempfile;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context {
    bind_options,
    context_program
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.unitree { Archetype }
import from jaclang.compiler.passes.layout_pass {
    archetype_native_name,
    class_type_native_name
}
import from jaclang.compiler.types.types { ClassType }

glob GAUGE_SRC: str = (
         "obj:pub Gauge {\n    has handle: int = 0;\n}\n\n"
         + "def:pub make_gauge(handle: int) -> Gauge {\n"
         + "    return Gauge(handle=handle);\n}\n"
     ),
     USE_SRC: str = "import from gauge { make_gauge }\n\nglob gauge_value = make_gauge(7);\n";

def check_options -> CompileOptions {
    return CompileOptions(no_cgen=True, native_parity=True, iface_ok=True);
}

test "an interface-described class takes its declaration's native name" {
    project = tempfile.mkdtemp();
    dep = os.path.realpath(os.path.join(project, "gauge.jac"));
    use = os.path.realpath(os.path.join(project, "use.jac"));
    with open(dep, "w") as handle {
        handle.write(GAUGE_SRC);
    }
    with open(use, "w") as handle {
        handle.write(USE_SRC);
    }
    first = JacProgram();
    first.compile(use, options=check_options());
    assert not first.errors_had , [e.pretty_print() for e in first.errors_had];
    declared = [a for a in first.mod.hub[dep].get_all_sub_nodes(Archetype)][0];
    native = archetype_native_name(declared);
    assert native != "Gauge" , "a program module's archetype keeps a scoped name";

    base = JacProgram();
    options = check_options();
    options.entry_point = use;
    program = context_program(base, bind_options(use, base, options));
    hydrated = program.load_dependency_module(dep);
    assert hydrated.stub_only , "the dependency should come from its interface";
    described = program.get_type_evaluator().get_type_of_symbol(
        hydrated.names_in_scope["Gauge"]
    );
    assert isinstance(described, ClassType);
    assert not isinstance(described.shared.symbol_table, Archetype) , (
        "the interface class should not carry the Archetype node"
    );
    assert class_type_native_name(described) == native , (
        f"{class_type_native_name(described)} != {native}"
    );
}

"""Native records of runtime package units serve every consumer.

A unit's native products are stamped by what shapes them, not by the
consumer's whole placement policy, so a record written for one program is
reused by the next one whose memory model and target agree.
"""
import os;
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }

def _pkg(rel: str) -> str {
    return os.path.join(jaclang_pkg_root(), rel);
}

test "a string-source compile reuses its dependencies' native records" {
    """A module compiled from a string has no cache entry of its own, but the
    runtime units it imports are files whose records serve every consumer;
    the second program must not lower them again.""";
    source = (
        "import os;\n"
        + "glob xs: list[int] = [len(os.getcwd())];\n"
        + "def f(a: dict[str, int]) -> str { return str(sorted(a.items())); }\n"
    );
    first = JacProgram();
    first.compile(file_path="native_records_probe_a.jac", use_str=source);
    assert not first.errors_had , [e.pretty_print() for e in first.errors_had];
    second = JacProgram();
    second.compile(file_path="native_records_probe_b.jac", use_str=source);
    assert not second.errors_had , [e.pretty_print() for e in second.errors_had];
    events = second.analysis.cache_events;
    if not events.get("native_unit_codegen", 0) {
        testskip("the probe module was not lowered natively, so no record is reused");
    }
    assert events.get("native_unit_lower", 0) == 0 , (
        f"the second program lowered runtime units again: {events}"
    );
    assert events.get("native_iface_hit", 0) > 0 , events;
}

test "a unit's native stamp ignores policy entries that name other modules" {
    registry = JacProgram().native_units();
    path = _pkg("runtime/region_native.jac");
    plain = registry.stamp_for(CompileOptions(), path);
    assert registry.stamp_for(
        CompileOptions(native_require=["jaclang.compiler.frontend.python.*"]), path
    ).matches(
        plain
    );
    assert registry.stamp_for(
        CompileOptions(target_app="web", app_kind="web"), path
    ).matches(
        plain
    );
    assert not registry.stamp_for(
        CompileOptions(native_require=["jaclang.runtime.*"]), path
    ).matches(
        plain
    ) , "a policy that names the unit changes its products";
    assert not registry.stamp_for(CompileOptions(memory_profile="nogc"), path).matches(
        plain
    );
}

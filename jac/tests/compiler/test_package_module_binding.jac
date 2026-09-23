"""Modules the running compiler package owns are analyzed canonically.

Whoever imports a package module, its analysis drops the consumer's
application, codespace and entry, so every consumer shares one context and
one cache identity for it, and its native products are stamped by what
shapes them rather than by the consumer's whole placement policy.
"""
import os;
import tempfile;
import from pathlib { Path }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.compilation_context {
    bind_options,
    context_identity,
    owner_scope_options
}
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.frontend.codeinfo { jaclang_pkg_root }

def _pkg(rel: str) -> str {
    return os.path.join(jaclang_pkg_root(), rel);
}

test "a package module drops the consumer's application and codespace" {
    prog = JacProgram();
    prog.options = CompileOptions(
        default_codespace="client",
        target_app="web",
        app_kind="web",
        ui="react",
        project_root="/tmp/app"
    );
    bound = bind_options(_pkg("cli/command.jac"), prog, prog.options);
    assert bound.package_canonical;
    assert bound.default_codespace == "" and bound.force_codespace == "";
    assert bound.target_app == "" and bound.app_kind == "" and bound.ui == "";
    assert bound.project_root is None;
    assert owner_scope_options(prog, bound) is None , (
        "a canonical analysis keys its cache the way the package's precompile does"
    );
    other = JacProgram();
    other.options = CompileOptions(default_codespace="server", target_app="api");
    assert context_identity(bound)
        == context_identity(
            bind_options(_pkg("cli/command.jac"), other, other.options)
        ) , ("every consumer shares one analysis context for the package");
}

test "an application module keeps the consumer's binding" {
    prog = JacProgram();
    prog.options = CompileOptions(
        default_codespace="client", target_app="web", app_kind="web"
    );
    with tempfile.TemporaryDirectory() as directory {
        source = Path(directory) / "page.jac";
        source.write_text("def page -> int { return 1; }\n");
        bound = bind_options(str(source), prog, prog.options);
        assert not bound.package_canonical;
        assert bound.default_codespace == "client" and bound.target_app == "web";
        assert owner_scope_options(prog, bound) is bound;
    }
}

test "a native unit build keeps its own options for package modules" {
    prog = JacProgram();
    prog.options = CompileOptions(
        aot_mode=True, native_unit=True, default_codespace="native"
    );
    bound = bind_options(_pkg("runtime/region_native.jac"), prog, prog.options);
    assert not bound.package_canonical;
    assert bound.default_codespace == "native";
}

test "the consumer's memory model and policy still shape a package module" {
    prog = JacProgram();
    prog.options = CompileOptions(
        memory_profile="nogc", native_require=["jaclang.cli.*"]
    );
    bound = bind_options(_pkg("cli/command.jac"), prog, prog.options);
    assert bound.package_canonical;
    assert bound.na_gc_mode == "none";
    assert bound.default_codespace == "native" and bound.force_codespace == "native";
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

"""Native host contracts use the same inherited members as ordinary calls."""

import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.compiler.session.options { CompileOptions }
import from jaclang.compiler.session.session { JacProgram }
import from jaclang.project.config { get_explicit_config, set_config }

def host_errors(
    hosts: str,
    cached_host: bool = False,
    native_source: str = 'import from raylib { def CloseWindow -> None; }\n'
    'def init -> int { CloseWindow(); return 0; }\n'
) -> list[str] {
    saved = get_explicit_config();
    set_config(None);
    try {
        with TemporaryDirectory() as directory {
            base = Path(directory);
            (base / "jac.toml").write_text('[project]\nname = "host"\n');
            (base / "native.jac").write_text(native_source);
            source = base / "main.jac";
            source.write_text(
                'import from "@jac/wasm_host" { bind_na_host }\n'
                'import from native { init }\n'
                    + hosts
                    + '\ndef bind { host: Host = Host(); bind_na_host(init, host); }\n'
            );
            program = JacProgram();
            module = program.compile(
                str(source),
                options=CompileOptions(
                    no_cgen=True, native_parity=True, force_codespace="client"
                )
            );
            if cached_host {
                import from jaclang.compiler.ir.schema { FuncCall, Name }
                import from jaclang.compiler.analysis.boundaries.wasm_contract {
                    check_host_call
                }
                import from jaclang.compiler.session.cache.catalog_paths {
                    jaclang_pkg_dir
                }
                import from jaclang.compiler.session.cache.interface_codec {
                    open_module_iface,
                    iface_module
                }
                import from jaclang.compiler.session.cache.catalog_reader { CatScope }
                import from jaclang.compiler.ir.types.nodes { ClassType }
                evaluator = program.get_type_evaluator();
                package = jaclang_pkg_dir();
                import from jaclang.compiler.pipeline.contracts { CompilationProduct }
                import from jaclang.compiler.pipeline.products { require_product }
                import from jaclang.compiler.pipeline.keys { INTERFACE }
                assert require_product(program, module, CompilationProduct.INTERFACE);
                payload = program.analysis.result(str(source), INTERFACE).data;
                assert payload is not None;
                catalog = open_module_iface(
                    payload, package, resolver=program.iface_registry()
                );
                assert catalog is not None;
                cached = iface_module(catalog);
                assert cached is not None;
                host_type = evaluator.get_type_of_symbol(cached.names_in_scope["Host"]);
                assert isinstance(host_type, ClassType);
                assert isinstance(host_type.shared.symbol_table, CatScope);
                call = next(
                    c
                    for c in module.get_all_sub_nodes(FuncCall)
                    if isinstance(c.target, Name) and c.target.value == "bind_na_host"
                );
                host_arg = call.params[1];
                assert isinstance(host_arg, Name);
                host_arg.narrowed_type = host_type.clone_as_instance();
                try {
                    check_host_call(call, program);
                } except ValueError as error {
                    return [str(error)];
                }
                return [];
            }
            return [str(error) for error in program.errors_had];
        }
    } finally {
        set_config(saved);
    }
}

test "host binding follows the class method resolution order" {
    errors = host_errors(
        'obj Left { def CloseWindow {} }\n'
        'obj Right { def CloseWindow(value: int) {} }\n'
        'obj Host(Left, Right) {}\n'
    );
    assert not errors , "\n".join(errors);
}

test "host binding validates the selected inherited method signature" {
    errors = host_errors(
        'obj Left { def CloseWindow(value: int) {} }\n'
        'obj Right { def CloseWindow {} }\n'
        'obj Host(Left, Right) {}\n'
    );
    assert any(
        "Host import 'CloseWindow' has incompatible signature" in e for e in errors
    );
}

test "nested classes cannot supply missing host methods" {
    errors = host_errors('obj Host { obj Nested { def CloseWindow {} } }\n');
    assert any("Host is missing native import 'CloseWindow'" in e for e in errors);
}

test "host binding accepts inherited methods loaded from an interface cache" {
    errors = host_errors(
        'obj Base { def CloseWindow {} }\nobj Host(Base) {}\n', cached_host=True
    );
    assert not errors , "\n".join(errors);
}

test "host binding validates inherited signatures loaded from an interface cache" {
    errors = host_errors(
        'obj Base { def CloseWindow(value: int) {} }\nobj Host(Base) {}\n',
        cached_host=True
    );
    assert any(
        "Host import 'CloseWindow' has incompatible signature" in e for e in errors
    );
}

test "host annotations cannot widen native scalar widths" {
    for (native_type, wide_type, primitive) in [
        ("i32", "i64", "int"),
        ("f32", "f64", "float")
    ] {
        for cached_host in [False, True] {
            for (param_type, return_type) in [
                (wide_type, primitive),
                (primitive, wide_type),
                (primitive, primitive)
            ] {
                errors = host_errors(
                    f'obj Host {{ def exchange(value: {param_type}) -> {return_type} {{ return {return_type}(value); }} }}\n',
                    cached_host=cached_host,
                    native_source=f'import from host_api {{ def exchange(value: {native_type}) -> {native_type}; }}\n'
                    f'def init -> {native_type} {{ return exchange({native_type}(0)); }}\n'
                );
                if param_type == primitive and return_type == primitive {
                    assert not errors , str(errors);
                } else {
                    assert any(
                        "Host import 'exchange' has incompatible signature" in e
                        for e in errors
                    ) , str(errors);
                }
            }
        }
    }
}

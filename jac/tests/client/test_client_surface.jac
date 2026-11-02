import from jaclang.client.client_surface { with_runtime_globals }

test "plain client modules do not acquire a framework dependency" {
    source = "export function calculate() { return 42; }";
    assert with_runtime_globals(source) == source;
}

test "client runtime globals are injected on demand and only once" {
    source = "export function invoke() { return __jacSpawn('Example', {}); }";
    generated = with_runtime_globals(source);
    assert generated.startswith('import {__jacSpawn} from "@jac/runtime";');
    assert "__jacJsx" not in generated;
    assert with_runtime_globals(generated) == generated;
}

test "a module that defines its runtime global keeps its own binding" {
    source = "function __jacSpawn() { return 42; }";
    assert with_runtime_globals(source) == source;
}

test "runtime globals are imported only when referenced and not declared at top level" {
    import from jaclang.compiler.backends.es.free_ident_audit {
        js_top_level_declarations
    }
    assert js_top_level_declarations(
        "export async function a() {}\nconst b = 1;\n  let nested = 2;\nclass C {}\n"
    )
        == {"a", "b", "C"};
    referenced = with_runtime_globals("__jacJsx('div', {}, []);\n");
    assert referenced.startswith("import {__jacJsx} from ") , referenced;
    declared = "function __jacJsx() {}\n__jacJsx('div', {}, []);\n";
    assert with_runtime_globals(declared) == declared;
    assert with_runtime_globals("let x = 1;\n") == "let x = 1;\n";
}

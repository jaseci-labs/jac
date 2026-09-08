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

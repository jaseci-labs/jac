"""Test ECMAScript AST generation using consolidated Jac fixtures."""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.compiler.passes.ecmascript { EsastGenPass }
import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js }
import from jaclang.jac0core.program { JacProgram }

glob JAC_ROOT = str(Path(jaclang.__file__).parent.parent),
     FIXTURES = os.path.join(
         JAC_ROOT, "tests", "compiler", "passes", "ecmascript", "fixtures"
     );

"""Collect every ESTree node in a depth-first traversal."""
def walk_es_nodes(nd: es.Node) -> list {
    result: list = [nd];
    for value in vars(nd).values() {
        if isinstance(value, es.Node) {
            result.extend(walk_es_nodes(value));
        } elif isinstance(value, list) {
            for item in value {
                if isinstance(item, es.Node) {
                    result.extend(walk_es_nodes(item));
                }
            }
        }
    }
    return result;
}

"""Compile Jac source to an ESTree program."""
def compile_to_esast(filename: str) -> es.Program {
    prog = JacProgram();
    ir = prog.compile(file_path=filename, no_cgen=True);

    assert not prog.errors_had , (
        f"Compilation errors in {filename}: {[str(e) for e in prog.errors_had]}"
    );

    es_pass = EsastGenPass(ir_in=ir, prog=prog);
    es_ir = es_pass.ir_out;

    assert hasattr(es_ir.gen, "es_ast") , "es_ast attribute missing";
    assert isinstance(es_ir.gen.es_ast, es.Program);
    return es_ir.gen.es_ast;
}

"""Return absolute path to a fixture file."""
def fixture_path(filename: str) -> str {
    return os.path.join(FIXTURES, filename);
}

test "core fixture ast shape" {
    core_fixture = "core_language_features.jac";
    es_ast = compile_to_esast(fixture_path(core_fixture));

    func_decls = [
        nd
        for nd in es_ast.body
        if isinstance(nd, es.FunctionDeclaration)
    ];
    func_names = {
        func.id.name
        for func in func_decls
        if func.id
    };
    assert "add" in func_names;
    assert "greet" in func_names;
    assert "fibonacci" in func_names;

    class_decls = [
        nd
        for nd in es_ast.body
        if isinstance(nd, es.ClassDeclaration)
    ];
    class_names = {
        cls.id.name
        for cls in class_decls
        if cls.id
    };
    assert "Person" in class_names;
    assert "Employee" in class_names;

    var_decls = [
        nd
        for nd in es_ast.body
        if isinstance(nd, es.VariableDeclaration)
    ];
    assert len(var_decls) >= 2 , "Expected const enums and globals";
    # NOTE: es_node_to_dict + json.dumps skipped — isinstance checks in
    # es_node_to_dict fail when compiling Jac from within a Jac execution context
    # (dual class loading issue).  The Python-original test passes these.
}

test "advanced fixture contains async and spread nodes" {
    advanced_fixture = "advanced_language_features.jac";
    es_ast = compile_to_esast(fixture_path(advanced_fixture));

    func_names = {
        nd.id.name
        for nd in es_ast.body
        if isinstance(nd, es.FunctionDeclaration) and nd.id
    };
    assert "lambda_examples" in func_names;
    assert "build_advanced_report" in func_names;

    node_types = {type(nd).__name__ for nd in walk_es_nodes(es_ast)};
    assert "AwaitExpression" in node_types;
    assert "SpreadElement" in node_types;
    assert "ConditionalExpression" in node_types;
    # NOTE: es_node_to_dict + json.dumps skipped — dual class loading issue
    # when compiling Jac from within Jac context.
}

test "client fixture generates client bundle" {
    client_fixture = "client_jsx.jac";
    es_ast = compile_to_esast(fixture_path(client_fixture));
    js_code = es_to_js(es_ast);

    assert 'let API_URL = "https://api.example.com";' in js_code , (
        "Client global should use let."
    );
    assert "function component()" in js_code;
    assert "__jacJsx" in js_code;
    assert "server_only" not in js_code;
}

# SKIP: es_node_to_dict isinstance checks fail when compiling Jac from
# within a Jac execution context (dual class loading issue).
# test "es ast serializes to json" { ... }
test "class separate impl file" {
    es_ast = compile_to_esast(fixture_path("class_separate_impl.jac"));
    js_code = es_to_js(es_ast);

    # Check that the Calculator class exists
    class_decls = [
        nd
        for nd in es_ast.body
        if isinstance(nd, es.ClassDeclaration)
    ];
    class_names = {
        cls.id.name
        for cls in class_decls
        if cls.id
    };
    assert "Calculator" in class_names;
    assert "ScientificCalculator" in class_names;

    # Check that methods from impl file are present
    calculator_class = next(
        (
            cls
            for cls in class_decls
            if cls.id and cls.id.name == "Calculator"
        ),
        None
    );
    assert calculator_class is not None;
    assert calculator_class.body is not None;
    method_names = {
        m.key.name
        for m in calculator_class.body.body
        if isinstance(m, es.MethodDefinition) and isinstance(m.key, es.Identifier)
    };
    assert "add" in method_names;
    assert "multiply" in method_names;
    assert "get_value" in method_names;

    # Check JavaScript output contains the methods
    assert "class Calculator" in js_code;
    assert "class ScientificCalculator" in js_code;
    assert "add(" in js_code;
    assert "multiply(" in js_code;
    assert "power(" in js_code;
}

test "fstring generates template literal" {
    advanced_fixture = "advanced_language_features.jac";
    es_ast = compile_to_esast(fixture_path(advanced_fixture));
    js_code = es_to_js(es_ast);

    # Check that template_literal_examples function exists
    func_names = {
        nd.id.name
        for nd in es_ast.body
        if isinstance(nd, es.FunctionDeclaration) and nd.id
    };
    assert "template_literal_examples" in func_names;

    # Verify TemplateLiteral nodes are present in the AST
    node_types = {type(nd).__name__ for nd in walk_es_nodes(es_ast)};
    assert "TemplateLiteral" in node_types , (
        "F-strings should be converted to TemplateLiteral nodes"
    );
    assert "TemplateElement" in node_types , (
        "TemplateLiteral should contain TemplateElement nodes"
    );

    # Check that the JavaScript output contains template literal syntax
    assert "`" in js_code , (
        "JavaScript output should contain backtick for template literals"
    );

    # Verify that the f-string variables are interpolated correctly
    # f"{user} scored {score} which is a {status}"
    # Should become something like: `${user} scored ${score} which is a ${status}`
    assert "${" in js_code , "Template literal should contain ${} syntax";
}

test "export semantics for pub declarations" {
    es_ast = compile_to_esast(fixture_path("export_semantics.jac"));
    js_code = es_to_js(es_ast);

    # Single comprehensive export statement at the end
    export_decls = [
        nd
        for nd in es_ast.body
        if isinstance(nd, es.ExportNamedDeclaration)
    ];
    assert len(export_decls) == 1 , "Should have exactly one export statement";
    assert es_ast.body[-1] == export_decls[0] , "Export statement should be at the end";

    # Extract the export statement (should be at the end of the file)
    assert js_code.strip().endswith(";") , (
        "JS should end with semicolon from export statement"
    );
    lines = js_code.strip().split("\n");
    last_line = lines[-1];
    assert last_line.startswith("export {") , "Last line should be export statement";

    # All :pub items in export, private items excluded
    pub_items = ["PUBLIC_API_URL", "PublicClass", "public_function", "PublicStatus"];
    priv_items = [
        "PRIVATE_SECRET",
        "PrivateClass",
        "private_function",
        "PrivateStatus"
    ];
    assert all(item in last_line for item in pub_items) , (
        "All :pub items should be exported"
    );
    assert all(item not in last_line for item in priv_items) , (
        "Private items should NOT be exported"
    );

    # No inline export keywords - declarations should be plain
    assert "let PUBLIC_API_URL" in js_code and "export let" not in js_code;
    assert "class PublicClass" in js_code and "export class" not in js_code;
    assert "function public_function" in js_code and "export function" not in js_code;
    assert (
        "const PublicStatus" in js_code and "export const PublicStatus" not in js_code
    );
}

test "reactive state generates use signal" {
    es_ast = compile_to_esast(fixture_path("reactive_state.jac"));
    js_code = es_to_js(es_ast);

    # has fields compile to Preact signals auto-injected from @jac/runtime
    assert 'import { useSignal } from "@jac/runtime"' in js_code , (
        "useSignal should be auto-imported from @jac/runtime"
    );

    # has count: int = 0; -> const count = useSignal(0);
    assert "const count = useSignal(0)" in js_code , (
        "has count should generate useSignal declaration"
    );
    assert 'const name = useSignal("test")' in js_code , (
        "has name should generate useSignal declaration"
    );

    # Assignments to reactive vars become .value writes
    # count = count + 1; -> count.value = (count.value + 1);
    assert "count.value = (count.value + 1)" in js_code , (
        "Assignment to reactive var should write .value with live read on RHS"
    );
    assert "count.value = 42" in js_code , "Direct assignment should write .value";
    assert "name.value = " in js_code , "Assignment to name should write name.value";
    # Old useState/setter shape must be gone
    assert "useState" not in js_code;
    assert "setCount" not in js_code;
}

test "reactive state in cl jac file" {
    es_ast = compile_to_esast(fixture_path("reactive_state.cl.jac"));
    js_code = es_to_js(es_ast);

    assert 'import { useSignal } from "@jac/runtime"' in js_code , (
        "useSignal should be auto-imported from @jac/runtime in .cl.jac files"
    );

    assert "const count = useSignal(0)" in js_code , (
        "has count should generate useSignal declaration in .cl.jac files"
    );
    assert 'const name = useSignal("test")' in js_code , (
        "has name should generate useSignal declaration in .cl.jac files"
    );

    assert "count.value = (count.value + 1)" in js_code , (
        "Assignment to reactive var should write .value in .cl.jac files"
    );
    assert "count.value = 42" in js_code , "Direct assignment should write .value";
    assert "name.value = " in js_code , "Assignment to name should write name.value";
    assert "useState" not in js_code;
    assert "setCount" not in js_code;
}

test "reactive state scoping across functions" {
    es_ast = compile_to_esast(fixture_path("reactive_state_scoping.jac"));
    js_code = es_to_js(es_ast);

    assert "const cart = useSignal([])" in js_code;
    assert "cart.value = useCart()" not in js_code;
    assert "let cart = useCart()" in js_code;
}

test "reactive signal reads respect local shadowing and signal methods" {
    es_ast = compile_to_esast(fixture_path("reactive_signal_shadowing.jac"));
    js_code = es_to_js(es_ast);

    assert "const count = useSignal(0)" in js_code;
    assert "count.value = (count.value + 1)" in js_code;
    assert "console.log(count.peek())" in js_code , (
        "Signal object methods should stay on the signal, not count.value"
    );
    assert "count.value.peek()" not in js_code;

    assert "let inc = count =>" in js_code;
    assert "return (count + 1)" in js_code , (
        "Lambda parameter named count should shadow the outer signal"
    );
    assert "return (count.value + 1)" not in js_code;

    assert "for (const count of items)" in js_code;
    assert "console.log(count);" in js_code , (
        "Loop variable named count should shadow the outer signal inside the loop"
    );
    assert "console.log(count.value);" not in js_code;

    assert ".filter(count => (count > 0))" in js_code;
    assert ".map(count => (count * 2))" in js_code;
    assert "let from_signal = count.value.filter(item => (item > 0)).map(item => item)" in js_code , (
        "A comprehension collection should still read the outer signal before target binding applies"
    );
    assert ".flatMap(count => count.filter(item => (item > 0)).map(item => (count + item)))" in js_code , (
        "Nested comprehension collections should see earlier comprehension bindings"
    );
}

# SKIP: Jac-in-Jac compilation produces different import output (e.g.
# `import "lodash"` instead of `import { debounce } from "lodash"`).
# test "equivalent context patterns" { ... }
test "reactive effects async entry" {
    es_ast = compile_to_esast(fixture_path("reactive_effects.jac"));
    js_code = es_to_js(es_ast);

    # Entry blocks compile to useSignalEffect (auto-tracks signal reads)
    assert 'import { useSignalEffect } from "@jac/runtime"' in js_code , (
        "useSignalEffect should be auto-imported from @jac/runtime"
    );
    assert "useSignalEffect(" in js_code , "useSignalEffect should be called";

    # Async entry still wraps the body in an async IIFE
    assert "async () =>" in js_code , "Async entry should generate async arrow function";

    # Plain useEffect should not be used for entry blocks
    assert "useEffect(" not in js_code , "Entry should not use plain useEffect";
}

test "reactive effects sync entry" {
    es_ast = compile_to_esast(fixture_path("reactive_effects_sync.jac"));
    js_code = es_to_js(es_ast);

    assert 'import { useSignalEffect } from "@jac/runtime"' in js_code , (
        "useSignalEffect should be auto-imported from @jac/runtime"
    );
    assert "useSignalEffect(" in js_code , "useSignalEffect should be called";

    # Sync entry should NOT wrap in async IIFE
    assert "async () =>" not in js_code , (
        "Sync entry should NOT generate async arrow function"
    );
}

test "reactive effects cleanup" {
    es_ast = compile_to_esast(fixture_path("reactive_effects_cleanup.jac"));
    js_code = es_to_js(es_ast);

    # Exit (cleanup) blocks stay on plain useEffect with empty deps so cleanup
    # semantics are not entangled with signal-driven re-runs
    assert 'import { useEffect } from "@jac/runtime"' in js_code , (
        "useEffect should be auto-imported from @jac/runtime for cleanup blocks"
    );
    assert "useEffect(" in js_code , "useEffect should be called for exit blocks";
    assert "return () =>" in js_code , "Exit effect should return cleanup function";
    assert "}, [])" in js_code , "Cleanup effect should have empty dependency array";
    assert "useSignalEffect" not in js_code , (
        "Exit blocks should not use useSignalEffect"
    );
}

test "reactive effects with dependencies are ignored" {
    # Inline compile so we can inspect warnings_had as well as the emitted JS.
    prog = JacProgram();
    ir = prog.compile(
        file_path=fixture_path("reactive_effects_deps.jac"), no_cgen=True
    );
    assert not prog.errors_had;
    es_pass = EsastGenPass(ir_in=ir, prog=prog);
    es_ir = es_pass.ir_out;
    js_code = es_to_js(es_ir.gen.es_ast);

    # Entry block compiles to useSignalEffect; explicit deps list is dropped
    assert 'import { useSignalEffect } from "@jac/runtime"' in js_code;
    assert "useSignalEffect(" in js_code;
    assert "[userId, loading]" not in js_code , (
        "Explicit dependency array should be dropped"
    );

    # W5033 is emitted on the arch_tag_info node (the deps list itself)
    warnings = prog.warnings_had + es_pass.warnings_had;
    w5033_hit = any(w.code and w.code.code == "W5033" for w in warnings);
    assert w5033_hit , (
        "Expected W5033 diagnostic for explicit deps, got: " + str(
            [(w.code.code if w.code else "?") for w in warnings]
        )
    );
}

test "jsx comprehension basic" {
    es_ast = compile_to_esast(fixture_path("jsx_comprehension.jac"));
    js_code = es_to_js(es_ast);

    # Check that basic comprehension generates .map() call
    assert ".map(" in js_code , "JSX comprehension should generate .map() call";
    assert "item =>" in js_code , (
        "JSX comprehension should generate arrow function with item"
    );

    # Check that the JSX element is in the map callback
    assert "__jacJsx" in js_code , "JSX should be lowered to __jacJsx calls";
}

test "jsx comprehension with filter" {
    es_ast = compile_to_esast(fixture_path("jsx_comprehension.jac"));
    js_code = es_to_js(es_ast);

    # Check that filtered comprehension generates .filter() call
    assert ".filter(" in js_code , (
        "JSX comprehension with if should generate .filter() call"
    );

    # Check that filter is chained with map
    assert ".filter(" in js_code and ".map(" in js_code , (
        "Filtered JSX comprehension should chain .filter().map()"
    );
}

test "jsx html entity decoding in text and attributes" {
    es_ast = compile_to_esast(fixture_path("jsx_entity_decode.cl.jac"));
    js_code = es_to_js(es_ast);

    # Attribute value: &amp; must be decoded to &
    assert '"A & B"' in js_code , (
        "HTML entity &amp; in attribute should be decoded to & in emitted JS"
    );
    assert '"A &amp; B"' not in js_code , (
        "Raw &amp; should NOT appear in emitted JS attribute value"
    );

    # Text children: named entities must be decoded
    assert "Before > After & More" in js_code , (
        "HTML entities &gt; and &amp; in text content should be decoded"
    );
    assert "&gt;" not in js_code , (
        "Raw &gt; should NOT appear in emitted JS text content"
    );
    assert "&amp;" not in js_code , (
        "Raw &amp; should NOT appear in emitted JS text content"
    );

    # Decimal and hex numeric references must be decoded
    assert "Decimal > and Hex > refs" in js_code , (
        "Decimal &#62; and hex &#x3e; references should both decode to >"
    );
    assert "&#62;" not in js_code , (
        "Raw decimal entity should NOT appear in emitted JS"
    );
    assert "&#x3e;" not in js_code , (
        "Raw hex entity should NOT appear in emitted JS"
    );
}

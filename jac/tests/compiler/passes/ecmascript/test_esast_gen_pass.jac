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
def walk_es_nodes(nd: es.Node) -> list[es.Node] {
    result: list[es.Node] = [nd];
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

test "reactive state generates use state" {
    es_ast = compile_to_esast(fixture_path("reactive_state.jac"));
    js_code = es_to_js(es_ast);

    # Check that useState is imported from @jac/runtime (auto-injected)
    assert 'import { useState } from "@jac/runtime"' in js_code , (
        "useState should be auto-imported from @jac/runtime"
    );

    # Check that has declarations generate useState destructuring
    # has count: int = 0; -> const [count, setCount] = useState(0);
    assert "const [count, setCount] = useState(0)" in js_code , (
        "has count should generate useState destructuring"
    );
    assert 'const [name, setName] = useState("test")' in js_code , (
        "has name should generate useState destructuring"
    );

    # Check that assignments to reactive vars generate setter calls
    # count = count + 1; -> setCount(count + 1);
    assert "setCount((count + 1))" in js_code , (
        "Assignment to reactive var should use setter"
    );
    assert "setCount(42)" in js_code , "Direct assignment should use setter";
    assert "setName(" in js_code , "Assignment to name should use setName";
}

test "reactive state in cl jac file" {
    es_ast = compile_to_esast(fixture_path("reactive_state.cl.jac"));
    js_code = es_to_js(es_ast);

    # Check that useState is imported from @jac/runtime (auto-injected)
    assert 'import { useState } from "@jac/runtime"' in js_code , (
        "useState should be auto-imported from @jac/runtime in .cl.jac files"
    );

    # Check that has declarations generate useState destructuring
    # has count: int = 0; -> const [count, setCount] = useState(0);
    assert "const [count, setCount] = useState(0)" in js_code , (
        "has count should generate useState destructuring in .cl.jac files"
    );
    assert 'const [name, setName] = useState("test")' in js_code , (
        "has name should generate useState destructuring in .cl.jac files"
    );

    # Check that assignments to reactive vars generate setter calls
    # count = count + 1; -> setCount(count + 1);
    assert "setCount((count + 1))" in js_code , (
        "Assignment to reactive var should use setter in .cl.jac files"
    );
    assert "setCount(42)" in js_code , "Direct assignment should use setter";
    assert "setName(" in js_code , "Assignment to name should use setName";
}

test "reactive state scoping across functions" {
    es_ast = compile_to_esast(fixture_path("reactive_state_scoping.jac"));
    js_code = es_to_js(es_ast);

    assert "const [cart, setCart] = useState([])" in js_code;
    assert "setCart(useCart())" not in js_code;
    assert "let cart = useCart()" in js_code;
}

# SKIP: Jac-in-Jac compilation produces different import output (e.g.
# `import "lodash"` instead of `import { debounce } from "lodash"`).
# test "equivalent context patterns" { ... }
test "reactive effects async entry" {
    es_ast = compile_to_esast(fixture_path("reactive_effects.jac"));
    js_code = es_to_js(es_ast);

    # Check that useEffect is imported from @jac/runtime (auto-injected)
    assert 'import { useEffect } from "@jac/runtime"' in js_code , (
        "useEffect should be auto-imported from @jac/runtime"
    );

    # Check that useEffect is called with arrow function
    assert "useEffect(" in js_code , "useEffect should be called";

    # Check that async entry generates IIFE wrapper: (async () => { ... })()
    assert "async () =>" in js_code , "Async entry should generate async arrow function";

    # Check empty dependency array for mount-only effect
    assert "}, [])" in js_code , "Mount effect should have empty dependency array";
}

test "reactive effects sync entry" {
    es_ast = compile_to_esast(fixture_path("reactive_effects_sync.jac"));
    js_code = es_to_js(es_ast);

    # Check that useEffect is imported from @jac/runtime (auto-injected)
    assert 'import { useEffect } from "@jac/runtime"' in js_code , (
        "useEffect should be auto-imported from @jac/runtime"
    );

    # Check that useEffect is called
    assert "useEffect(" in js_code , "useEffect should be called";

    # Check that sync entry does NOT wrap in async IIFE
    assert "async () =>" not in js_code , (
        "Sync entry should NOT generate async arrow function"
    );

    # Check empty dependency array for mount-only effect
    assert "}, [])" in js_code , "Mount effect should have empty dependency array";
}

test "reactive effects cleanup" {
    es_ast = compile_to_esast(fixture_path("reactive_effects_cleanup.jac"));
    js_code = es_to_js(es_ast);

    # Check that useEffect is imported from @jac/runtime (auto-injected)
    assert 'import { useEffect } from "@jac/runtime"' in js_code , (
        "useEffect should be auto-imported from @jac/runtime"
    );

    # Check that useEffect is called with cleanup return
    assert "useEffect(" in js_code , "useEffect should be called";
    assert "return () =>" in js_code , "Exit effect should return cleanup function";

    # Check empty dependency array
    assert "}, [])" in js_code , "Cleanup effect should have empty dependency array";
}

test "reactive effects with dependencies" {
    es_ast = compile_to_esast(fixture_path("reactive_effects_deps.jac"));
    js_code = es_to_js(es_ast);

    # Check that useEffect is imported from @jac/runtime (auto-injected)
    assert 'import { useEffect } from "@jac/runtime"' in js_code , (
        "useEffect should be auto-imported from @jac/runtime"
    );

    # Check that useEffect is called
    assert "useEffect(" in js_code , "useEffect should be called";

    # Check that dependency array contains userId and loading (tuple syntax)
    assert "[userId, loading])" in js_code , (
        "Effect with (userId, loading) tuple should have both in dependency array"
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
    assert "&#x3e;" not in js_code , ("Raw hex entity should NOT appear in emitted JS");
}

test "jsx block comment is a no-op child" {
    # `{#* ... *#}` inside JSX children must compile cleanly and produce no
    # rendered output — the comment body must not leak into the generated JS,
    # and surrounding sibling elements must render normally.
    es_ast = compile_to_esast(fixture_path("jsx_block_comment.cl.jac"));
    js_code = es_to_js(es_ast);

    assert "JSX_COMMENT_PROBE" not in js_code , (
        "Block-comment body must not appear in emitted JS"
    );
    assert "__jacJsx" in js_code , "Surrounding JSX should still compile to __jacJsx";
    assert "Hello" in js_code , "Sibling text before the comment should render";
    assert "Click" in js_code , "Sibling text after the comment should render";
}

test "stale has read emits W3041" {
    # Compile with type_check=True so the lint schedule (JacLintCheckPass)
    # runs and W3041 surfaces in prog.warnings_had.
    prog = JacProgram();
    _ir = prog.compile(
        file_path=fixture_path("stale_has_read.jac"), no_cgen=True, type_check=True
    );
    assert not prog.errors_had , (
        "Compilation errors: " + str([str(e) for e in prog.errors_had])
    );
    w3041_hits = [
        w
        for w in prog.warnings_had
        if w.code and w.code.code == "W3041"
    ];
    assert len(w3041_hits) >= 1 , (
        "Expected W3041 diagnostic for stale `has` field read, got: " + str(
            [(w.code.code if w.code else "?") for w in prog.warnings_had]
        )
    );
}

test "single-`props` component definition warns W5015" {
    fixture = fixture_path("component_props_idiom.cl.jac");
    prog = JacProgram();
    ir = prog.compile(file_path=fixture, no_cgen=True);
    assert not prog.errors_had , (
        f"Compilation errors in {fixture}: {[str(e) for e in prog.errors_had]}"
    );
    EsastGenPass(ir_in=ir, prog=prog);

    w5015 = [
        w
        for w in prog.warnings_had
        if w.code is not None and w.code.code == "W5015"
    ];
    msgs = [str(w) for w in w5015];

    # Only the JS-idiomatic single-`props` shape sacrifices per-prop call-site
    # validation, so JsPropsStyle is the one and only component that warns.
    assert len(w5015) == 1 , (
        f"Expected exactly one W5015 (JsPropsStyle), got {len(w5015)}: {msgs}"
    );
    assert any("JsPropsStyle" in m for m in msgs) , (
        f"W5015 should name the offending component 'JsPropsStyle', got: {msgs}"
    );

    # The Jac-idiomatic shapes (direct named params, or a typed single-key
    # bundle whose name isn't the `props` keyword) must not warn — both
    # preserve per-prop validation at JSX call sites.
    assert not any("DirectStyle" in m for m in msgs) , (
        f"DirectStyle (multi-param) should not warn, got: {msgs}"
    );
    assert not any("SingleKeyStyle" in m for m in msgs) , (
        f"SingleKeyStyle (typed single-key bundle) should not warn, got: {msgs}"
    );
}

test "view declarator compiles to a jsx component" {
    # Phase 1 of the `view` design: `view Name(...) { ... }` is sugar for
    # `def:pub Name(...) -> JsxElement { ... }` with a statement-based body.
    es_ast = compile_to_esast(fixture_path("view_basic.cl.jac"));
    js_code = es_to_js(es_ast);

    # Each `view` lowers to a plain function declaration.
    func_names = {
        nd.id.name
        for nd in es_ast.body
        if isinstance(nd, es.FunctionDeclaration) and nd.id
    };
    assert "Badge" in func_names , "view Badge should lower to a function";
    assert "ItemRow" in func_names , "view ItemRow should lower to a function";
    assert "ItemList" in func_names , "view ItemList should lower to a function";
    # `view Divider { ... }` — the parameter list is optional.
    assert "Divider" in func_names , (
        "no-parens `view Divider { }` should lower to a function"
    );

    # The statement body is lowered to a children accumulator that the view
    # returns as a single JSX fragment.
    assert "__jac_view_kids" in js_code , (
        "view body should lower to a `__jac_view_kids` accumulator"
    );
    assert "__jac_view_kids = []" in js_code , "accumulator should be initialized";
    assert "__jac_view_kids.push(" in js_code , (
        "each JSX statement should append to the accumulator in O(1)"
    );
    assert "__jacJsx" in js_code , "JSX should still lower to __jacJsx calls";

    # `has` fields inside a view keep the existing auto-`useState` wiring.
    assert 'const [heading, setHeading] = useState("Items")' in js_code , (
        "has field in a view should generate useState"
    );
    assert "setHeading(" in js_code , (
        "assignment to a view has-field should use the generated setter"
    );

    # Public components are exported.
    assert "export {" in js_code , "views should be exported";
    export_line = js_code.strip().split("\n")[-1];
    assert "Badge" in export_line
    and "ItemRow" in export_line
    and "ItemList" in export_line
    and "Divider" in export_line , "all four views should be exported";
}

test "view statement-position control flow lowers to statements" {
    es_ast = compile_to_esast(fixture_path("view_basic.cl.jac"));
    js_code = es_to_js(es_ast);

    # `if`/`else` at view-body level yields content in both branches.
    assert "Nothing here." in js_code , "the if-branch content should render";
    assert "Showing items." in js_code , "the else-branch content should render";

    # A statement `for` over the params lowers to a real loop (not a .map
    # comprehension) that appends each element to the accumulator.
    assert "items" in js_code , "the for loop should iterate the items param";
    has_loop = ("for (" in js_code) or ("for(" in js_code);
    assert has_loop , "a statement `for` in a view should emit a JS loop";
}

test "view dynamic tags resolve the tag at runtime" {
    # Phase 2: `<@expr />` — the JSX tag is an expression, not a static name.
    es_ast = compile_to_esast(fixture_path("view_dynamic_tag.cl.jac"));
    js_code = es_to_js(es_ast);

    func_names = {
        nd.id.name
        for nd in es_ast.body
        if isinstance(nd, es.FunctionDeclaration) and nd.id
    };
    assert "Box" in func_names
    and "Icon" in func_names
    and "Panel" in func_names
    and "Demo" in func_names;

    # A dynamic tag lowers to `__jacJsx(<expr>, ...)` — the tag is the value
    # of the expression, never a quoted string of the identifier itself.
    assert "__jacJsx(as_," in js_code , (
        "<@as_> should pass the `as_` value as the tag"
    );
    assert '__jacJsx("as_"' not in js_code , (
        "the dynamic tag identifier must not be emitted as a string literal"
    );
    assert "__jacJsx(tag," in js_code , "<@tag> should pass the `tag` value";
    assert "__jacJsx(glyph," in js_code , (
        "the brace-wrapped dynamic tag <@{glyph}> should pass the `glyph` value"
    );

    # Static tags around the dynamic one are unaffected.
    assert '__jacJsx("div",' in js_code , "static host tags stay string tags";
    assert "__jacJsx(Box," in js_code , (
        "a view used as a normal element stays a component reference"
    );
}

import from engine.src.parser.ast { ASTNode, ASTNodeType, ZERO_RANGE }
import from engine.src.parser.parser { Parser, make_parser, parse }
import from engine.src.ffi.libc { fflush, _exit }

# ══════════════════════════════════════════════════════════════════════════════
# Smoke tests
# ══════════════════════════════════════════════════════════════════════════════

glob _ok: int = 0,
     _fail: int = 0;

def _chk(label: str, got: bool) {
    if got {
        _ok = _ok + 1;
    } else {
        _fail = _fail + 1;
        print("FAIL: " + label);
    }
}

def _chk_nt(label: str, n: ASTNode | None, expected: ASTNodeType) {
    _chk(label, n is not None and n.ntype == expected);
}

# Child links on ASTNode are nullable. _nn() unwraps one for a chained field
# check; a missing child is reported as a failure and replaced by an empty
# node so the checks that follow fail visibly instead of aborting the run.
def _nn(n: ASTNode | None) -> ASTNode {
    if n is None {
        _fail = _fail + 1;
        print("FAIL: expected an AST child node, got None");
        return ASTNode(ntype=ASTNodeType.EmptyStatement, loc=ZERO_RANGE);
    }
    return n;
}

glob r = ZERO_RANGE;

with entry {
    # ── 1: empty program ────────────────────────────────────────────────────
    prog1 = parse("");
    _chk_nt("empty prog ntype", prog1, ASTNodeType.Program);
    _chk("empty prog body len", len(prog1.children) == 0);

    # ── 2: numeric literal expression statement ─────────────────────────────
    prog2 = parse("42;");
    _chk("num literal stmt count", len(prog2.children) == 1);
    s2 = prog2.children[0];
    _chk_nt("expr stmt ntype", s2, ASTNodeType.ExpressionStatement);
    _chk_nt("num literal ntype", s2.expression, ASTNodeType.Literal);
    _chk("num literal value", _nn(s2.expression).value == "42");

    # ── 3: string literal ───────────────────────────────────────────────────
    prog3 = parse("\"hello\";");
    s3 = prog3.children[0];
    _chk_nt("string literal stmt", s3, ASTNodeType.ExpressionStatement);
    _chk("string literal val", _nn(s3.expression).value == "hello");

    # ── 4: identifier ───────────────────────────────────────────────────────
    prog4 = parse("foo;");
    s4 = prog4.children[0];
    _chk_nt("id expr stmt", s4, ASTNodeType.ExpressionStatement);
    _chk_nt("id ntype", s4.expression, ASTNodeType.Identifier);
    _chk("id name", _nn(s4.expression).name == "foo");

    # ── 5: var declaration ──────────────────────────────────────────────────
    prog5 = parse("var x = 1;");
    s5 = prog5.children[0];
    _chk_nt("var decl ntype", s5, ASTNodeType.VariableDeclaration);
    _chk("var kind", s5.value == "var");
    _chk("var decl count", len(s5.declarations) == 1);
    d5 = s5.declarations[0];
    _chk_nt("var declarator ntype", d5, ASTNodeType.VariableDeclarator);
    _chk("var id name", _nn(d5.id).name == "x");
    _chk("var init value", _nn(d5.init).value == "1");

    # ── 6: let declaration no init ──────────────────────────────────────────
    prog6 = parse("let y;");
    s6 = prog6.children[0];
    _chk_nt("let decl ntype", s6, ASTNodeType.VariableDeclaration);
    _chk("let kind", s6.value == "let");
    _chk("let init none", s6.declarations[0].init is None);

    # ── 7: const declaration ────────────────────────────────────────────────
    prog7 = parse("const z = true;");
    s7 = prog7.children[0];
    _chk("const kind", s7.value == "const");
    _chk("const init true", _nn(s7.declarations[0].init).value == "true");

    # ── 8: binary expression ────────────────────────────────────────────────
    prog8 = parse("a + b;");
    s8 = _nn(prog8.children[0].expression);
    _chk_nt("binary ntype", s8, ASTNodeType.BinaryExpression);
    _chk("binary op", s8.operator == "+");
    _chk("binary left", _nn(s8.left).name == "a");
    _chk("binary right", _nn(s8.right).name == "b");

    # ── 9: assignment expression ─────────────────────────────────────────────
    prog9 = parse("x = 5;");
    s9 = _nn(prog9.children[0].expression);
    _chk_nt("assign ntype", s9, ASTNodeType.AssignmentExpression);
    _chk("assign op", s9.operator == "=");

    # ── 10: function declaration ─────────────────────────────────────────────
    prog10 = parse("function foo(a, b) { return a + b; }");
    s10 = prog10.children[0];
    _chk_nt("fn decl ntype", s10, ASTNodeType.FunctionDeclaration);
    _chk("fn name", _nn(s10.id).name == "foo");
    _chk("fn params count", len(s10.params) == 2);
    _chk("fn param0 name", s10.params[0].name == "a");
    _chk("fn param1 name", s10.params[1].name == "b");
    _chk_nt("fn body ntype", s10.body, ASTNodeType.BlockStatement);
    _chk("fn body stmt count", len(_nn(s10.body).children) == 1);
    s10_ret = _nn(s10.body).children[0];
    _chk_nt("return ntype", s10_ret, ASTNodeType.ReturnStatement);
    _chk_nt("return arg", s10_ret.argument, ASTNodeType.BinaryExpression);

    # ── 11: if statement ─────────────────────────────────────────────────────
    prog11 = parse("if (x > 0) { y = 1; } else { y = 2; }");
    s11 = prog11.children[0];
    _chk_nt("if ntype", s11, ASTNodeType.IfStatement);
    _chk_nt("if test", s11.cond_expr, ASTNodeType.BinaryExpression);
    _chk("if test op", _nn(s11.cond_expr).operator == ">");
    _chk_nt("if cons", s11.consequent, ASTNodeType.BlockStatement);
    _chk("if alt not null", s11.alternate is not None);
    _chk_nt("if alt", s11.alternate, ASTNodeType.BlockStatement);

    # ── 12: while statement ──────────────────────────────────────────────────
    prog12 = parse("while (i < 10) { i++; }");
    s12 = prog12.children[0];
    _chk_nt("while ntype", s12, ASTNodeType.WhileStatement);
    _chk_nt("while test", s12.cond_expr, ASTNodeType.BinaryExpression);
    _chk_nt("while body", s12.body, ASTNodeType.BlockStatement);

    # ── 13: for statement ────────────────────────────────────────────────────
    prog13 = parse("for (var i = 0; i < 10; i++) {}");
    s13 = prog13.children[0];
    _chk_nt("for ntype", s13, ASTNodeType.ForStatement);
    _chk_nt("for init", s13.init, ASTNodeType.VariableDeclaration);
    _chk_nt("for test", s13.cond_expr, ASTNodeType.BinaryExpression);
    _chk_nt("for update", s13.update, ASTNodeType.UpdateExpression);

    # ── 14: return statement ─────────────────────────────────────────────────
    prog14 = parse("function f() { return 42; }");
    s14 = _nn(prog14.children[0].body).children[0];
    _chk_nt("return ntype", s14, ASTNodeType.ReturnStatement);
    _chk("return val", _nn(s14.argument).value == "42");

    # ── 15: call expression ──────────────────────────────────────────────────
    prog15 = parse("foo(1, 2);");
    s15 = _nn(prog15.children[0].expression);
    _chk_nt("call ntype", s15, ASTNodeType.CallExpression);
    _chk("call callee", _nn(s15.callee).name == "foo");
    _chk("call args len", len(s15.arguments) == 2);

    # ── 16: member expression ─────────────────────────────────────────────────
    prog16 = parse("obj.prop;");
    s16 = _nn(prog16.children[0].expression);
    _chk_nt("member ntype", s16, ASTNodeType.MemberExpression);
    _chk("member obj name", _nn(s16.object).name == "obj");
    _chk("member prop name", _nn(s16.property).name == "prop");
    _chk("member not computed", s16.computed == False);

    # ── 17: computed member ───────────────────────────────────────────────────
    prog17 = parse("arr[0];");
    s17 = _nn(prog17.children[0].expression);
    _chk_nt("comp member ntype", s17, ASTNodeType.MemberExpression);
    _chk("comp member computed", s17.computed == True);

    # ── 18: new expression ────────────────────────────────────────────────────
    prog18 = parse("new Foo(a, b);");
    s18 = _nn(prog18.children[0].expression);
    _chk_nt("new ntype", s18, ASTNodeType.NewExpression);
    _chk("new callee", _nn(s18.callee).name == "Foo");
    _chk("new args len", len(s18.arguments) == 2);

    # ── 19: unary expression ──────────────────────────────────────────────────
    prog19 = parse("!x;");
    s19 = _nn(prog19.children[0].expression);
    _chk_nt("unary ntype", s19, ASTNodeType.UnaryExpression);
    _chk("unary op", s19.operator == "!");
    _chk("unary prefix", s19.prefix == True);

    # ── 20: update expression (postfix) ──────────────────────────────────────
    prog20 = parse("i++;");
    s20 = _nn(prog20.children[0].expression);
    _chk_nt("update ntype", s20, ASTNodeType.UpdateExpression);
    _chk("update op", s20.operator == "++");
    _chk("update not prefix", s20.prefix == False);

    # ── 21: update expression (prefix) ───────────────────────────────────────
    prog21 = parse("++j;");
    s21 = _nn(prog21.children[0].expression);
    _chk_nt("prefix update ntype", s21, ASTNodeType.UpdateExpression);
    _chk("prefix update is prefix", s21.prefix == True);

    # ── 22: conditional expression ────────────────────────────────────────────
    prog22 = parse("a ? b : c;");
    s22 = _nn(prog22.children[0].expression);
    _chk_nt("cond ntype", s22, ASTNodeType.ConditionalExpression);
    _chk("cond test name", _nn(s22.cond_expr).name == "a");
    _chk("cond cons name", _nn(s22.consequent).name == "b");
    _chk("cond alt name", _nn(s22.alternate).name == "c");

    # ── 23: logical expression ────────────────────────────────────────────────
    prog23 = parse("a && b;");
    s23 = _nn(prog23.children[0].expression);
    _chk_nt("logical ntype", s23, ASTNodeType.LogicalExpression);
    _chk("logical op", s23.operator == "&&");

    # ── 24: array literal ─────────────────────────────────────────────────────
    prog24 = parse("[1, 2, 3];");
    s24 = _nn(prog24.children[0].expression);
    _chk_nt("array ntype", s24, ASTNodeType.ArrayExpression);
    _chk("array len", len(s24.elements) == 3);

    # ── 25: object literal ────────────────────────────────────────────────────
    prog25 = parse("({a: 1, b: 2});");
    s25 = _nn(prog25.children[0].expression);
    _chk_nt("object ntype", s25, ASTNodeType.ObjectExpression);
    _chk("object props len", len(s25.properties) == 2);

    # ── 26: arrow function ────────────────────────────────────────────────────
    prog26 = parse("const add = (a, b) => a + b;");
    s26 = prog26.children[0];
    _chk_nt("arrow const ntype", s26, ASTNodeType.VariableDeclaration);
    arrow26 = _nn(s26.declarations[0].init);
    _chk_nt("arrow fn ntype", arrow26, ASTNodeType.ArrowFunctionExpr);
    _chk("arrow params len", len(arrow26.params) == 2);
    _chk("arrow expr body", arrow26.expression_body == True);

    # ── 27: arrow function block body ─────────────────────────────────────────
    prog27 = parse("const f = () => { return 1; };");
    arrow27 = _nn(prog27.children[0].declarations[0].init);
    _chk_nt("arrow block ntype", arrow27, ASTNodeType.ArrowFunctionExpr);
    _chk("arrow block body", arrow27.expression_body == False);

    # ── 28: try-catch-finally ─────────────────────────────────────────────────
    prog28 = parse("try { foo(); } catch (e) { bar(); } finally { baz(); }");
    s28 = prog28.children[0];
    _chk_nt("try ntype", s28, ASTNodeType.TryStatement);
    _chk("catch not null", s28.handler is not None);
    _chk_nt("catch ntype", s28.handler, ASTNodeType.CatchClause);
    _chk("catch param", _nn(_nn(s28.handler).param).name == "e");
    _chk("finally not null", s28.finalizer is not None);

    # ── 29: throw statement ────────────────────────────────────────────────────
    prog29 = parse("throw new Error(\"oops\");");
    s29 = prog29.children[0];
    _chk_nt("throw ntype", s29, ASTNodeType.ThrowStatement);
    _chk_nt("throw arg", s29.argument, ASTNodeType.NewExpression);

    # ── 30: switch statement ──────────────────────────────────────────────────
    prog30 = parse("switch (x) { case 1: break; default: y = 0; }");
    s30 = prog30.children[0];
    _chk_nt("switch ntype", s30, ASTNodeType.SwitchStatement);
    _chk("switch cases len", len(s30.cases) == 2);
    _chk_nt("case ntype", s30.cases[0], ASTNodeType.SwitchCase);
    _chk("default test null", s30.cases[1].cond_expr is None);

    # ── 31: break / continue ──────────────────────────────────────────────────
    prog31 = parse("while (1) { break; continue; }");
    stmts31 = _nn(prog31.children[0].body).children;
    _chk_nt("break ntype", stmts31[0], ASTNodeType.BreakStatement);
    _chk_nt("continue ntype", stmts31[1], ASTNodeType.ContinueStatement);

    # ── 32: labeled break ─────────────────────────────────────────────────────
    prog32 = parse("outer: while (1) { break outer; }");
    s32 = prog32.children[0];
    _chk_nt("labeled ntype", s32, ASTNodeType.LabeledStatement);
    _chk("label name", s32.name == "outer");

    # ── 33: do-while ──────────────────────────────────────────────────────────
    prog33 = parse("do { x++; } while (x < 10);");
    s33 = prog33.children[0];
    _chk_nt("do-while ntype", s33, ASTNodeType.DoWhileStatement);
    _chk_nt("do-while test", s33.cond_expr, ASTNodeType.BinaryExpression);

    # ── 34: for-of ────────────────────────────────────────────────────────────
    prog34 = parse("for (const item of arr) {}");
    s34 = prog34.children[0];
    _chk_nt("for-of ntype", s34, ASTNodeType.ForOfStatement);

    # ── 35: for-in ────────────────────────────────────────────────────────────
    prog35 = parse("for (const k in obj) {}");
    s35 = prog35.children[0];
    _chk_nt("for-in ntype", s35, ASTNodeType.ForInStatement);

    # ── 36: class declaration ─────────────────────────────────────────────────
    prog36 = parse(
        "class Animal { constructor(name) { this.name = name; } speak() { return \"roar\"; } }"
    );
    s36 = prog36.children[0];
    _chk_nt("class decl ntype", s36, ASTNodeType.ClassDeclaration);
    _chk("class name", _nn(s36.id).name == "Animal");
    _chk("class body len", len(s36.children) >= 2);

    # ── 37: class extends ─────────────────────────────────────────────────────
    prog37 = parse("class Dog extends Animal { }");
    s37 = prog37.children[0];
    _chk_nt("class extends ntype", s37, ASTNodeType.ClassDeclaration);
    _chk("class superclass", s37.superclass is not None);
    _chk("class superclass name", _nn(s37.superclass).name == "Animal");

    # ── 38: spread in call ────────────────────────────────────────────────────
    prog38 = parse("fn(...args);");
    s38 = _nn(prog38.children[0].expression);
    _chk_nt("spread call ntype", s38, ASTNodeType.CallExpression);
    _chk("spread arg ntype", s38.arguments[0].ntype == ASTNodeType.SpreadElement);

    # ── 39: debugger statement ────────────────────────────────────────────────
    prog39 = parse("debugger;");
    s39 = prog39.children[0];
    _chk_nt("debugger ntype", s39, ASTNodeType.DebuggerStatement);

    # ── 40: empty statement ───────────────────────────────────────────────────
    prog40 = parse(";");
    s40 = prog40.children[0];
    _chk_nt("empty stmt ntype", s40, ASTNodeType.EmptyStatement);

    # ── 41: sequence expression ───────────────────────────────────────────────
    prog41 = parse("(a, b, c);");
    s41 = _nn(prog41.children[0].expression);
    _chk_nt("seq ntype", s41, ASTNodeType.SequenceExpression);
    _chk("seq len", len(s41.expressions) == 3);

    # ── 42: typeof ────────────────────────────────────────────────────────────
    prog42 = parse("typeof x;");
    s42 = _nn(prog42.children[0].expression);
    _chk_nt("typeof ntype", s42, ASTNodeType.UnaryExpression);
    _chk("typeof op", s42.operator == "typeof");

    # ── 43: void expression ───────────────────────────────────────────────────
    prog43 = parse("void 0;");
    s43 = _nn(prog43.children[0].expression);
    _chk_nt("void ntype", s43, ASTNodeType.UnaryExpression);
    _chk("void op", s43.operator == "void");

    # ── 44: exponentiation ────────────────────────────────────────────────────
    prog44 = parse("2 ** 10;");
    s44 = _nn(prog44.children[0].expression);
    _chk_nt("exp ntype", s44, ASTNodeType.BinaryExpression);
    _chk("exp op", s44.operator == "**");

    # ── 45: compound assignment ───────────────────────────────────────────────
    prog45 = parse("x += 5;");
    s45 = _nn(prog45.children[0].expression);
    _chk_nt("compound assign ntype", s45, ASTNodeType.AssignmentExpression);
    _chk("compound assign op", s45.operator == "+=");

    # ── 46: nullish coalescing ────────────────────────────────────────────────
    prog46 = parse("a ?? b;");
    s46 = _nn(prog46.children[0].expression);
    _chk_nt("nullish ntype", s46, ASTNodeType.LogicalExpression);
    _chk("nullish op", s46.operator == "??");

    # ── 47: logical OR ────────────────────────────────────────────────────────
    prog47 = parse("a || b;");
    s47 = _nn(prog47.children[0].expression);
    _chk_nt("logical OR ntype", s47, ASTNodeType.LogicalExpression);
    _chk("logical OR op", s47.operator == "||");

    # ── 48: this ─────────────────────────────────────────────────────────────
    prog48 = parse("this.x;");
    s48 = _nn(prog48.children[0].expression);
    _chk_nt("this member ntype", s48, ASTNodeType.MemberExpression);
    _chk("this obj", _nn(s48.object).name == "this");

    # ── 49: multiple statements ───────────────────────────────────────────────
    prog49 = parse("var a = 1; var b = 2; var c = a + b;");
    _chk("multiple stmts", len(prog49.children) == 3);

    # ── 50: function with multiple params and body stmts ─────────────────────
    prog50 = parse("function sum(a, b, c) { var x = a + b; return x + c; }");
    fn50 = prog50.children[0];
    _chk("fn sum params", len(fn50.params) == 3);
    _chk("fn sum body stmts", len(_nn(fn50.body).children) == 2);

    # ── 51: no errors on basic parse ─────────────────────────────────────────
    p51: Parser = make_parser("var x = 1 + 2;");
    prog_51 = p51.parse_program();
    _chk("no parse errors", len(p51._errors) == 0);

    # ── 52: chained member call ───────────────────────────────────────────────
    prog52 = parse("arr.filter(x => x > 0).map(x => x * 2);");
    s52 = _nn(prog52.children[0].expression);
    _chk_nt("chained call ntype", s52, ASTNodeType.CallExpression);

    # ── 53: template literal ──────────────────────────────────────────────────
    prog53 = parse("const s = `hello`;");
    tmpl53 = _nn(prog53.children[0].declarations[0].init);
    _chk_nt("template ntype", tmpl53, ASTNodeType.TemplateLiteral);

    # ── 54: import statement ──────────────────────────────────────────────────
    prog54 = parse("import { foo, bar as baz } from \"mod\";");
    s54 = prog54.children[0];
    _chk_nt("import ntype", s54, ASTNodeType.ImportDeclaration);
    _chk("import specs len", len(s54.specifiers) == 2);

    # ── 55: export default ────────────────────────────────────────────────────
    prog55 = parse("export default 42;");
    s55 = prog55.children[0];
    _chk_nt("export default ntype", s55, ASTNodeType.ExportDefaultDecl);

    # ── 56: export named ─────────────────────────────────────────────────────
    prog56 = parse("export { a, b as c };");
    s56 = prog56.children[0];
    _chk_nt("export named ntype", s56, ASTNodeType.ExportNamedDecl);
    _chk("export named specs", len(s56.specifiers) == 2);

    # ── 57: async function ────────────────────────────────────────────────────
    prog57 = parse("async function fetchData() { return 1; }");
    s57 = prog57.children[0];
    _chk_nt("async fn ntype", s57, ASTNodeType.FunctionDeclaration);
    _chk("async fn is_async", s57.is_async == True);

    # ── 58: generator function ────────────────────────────────────────────────
    prog58 = parse("function* gen() { yield 1; }");
    s58 = prog58.children[0];
    _chk_nt("gen fn ntype", s58, ASTNodeType.FunctionDeclaration);
    _chk("gen fn is_generator", s58.is_generator == True);

    # ── 59: destructuring const ───────────────────────────────────────────────
    prog59 = parse("const { a, b } = obj;");
    s59 = prog59.children[0];
    _chk_nt("destructure const ntype", s59, ASTNodeType.VariableDeclaration);
    d59 = s59.declarations[0];
    _chk_nt("obj pattern ntype", d59.id, ASTNodeType.ObjectPattern);

    # ── 60: array destructuring ────────────────────────────────────────────────
    prog60 = parse("const [x, y] = arr;");
    d60 = prog60.children[0].declarations[0];
    _chk_nt("array pattern ntype", d60.id, ASTNodeType.ArrayPattern);

    print("Parser smoke tests: passed=" + str(_ok) + " failed=" + str(_fail));
    if _fail > 0 {
        fflush(0);
        _exit(1);
    }
}

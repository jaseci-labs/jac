"""
js_engine/main.na.jac — JS engine entry point.

Edit the three config lines in `with entry` to choose the JS file and debug flags:
    JS_FILE    — path to the JS file to run
    FLAG_AST   — True → print the parsed JS AST
    FLAG_BC    — True → print disassembled bytecode
    FLAG_RUN   — True → execute the script
    FLAG_DEBUG — True → print debug messages (file info, timing, etc.)
"""

import from engine.src.parser.parser { parse }
import from engine.src.parser.ast { ASTNodeType, ASTNode }
import from engine.src.bytecode.compiler { make_compiler }
import from engine.src.bytecode.op { disassemble, CompiledFunction }
import from engine.src.bytecode.regisa { reg_disassemble, reg_translate_fn }
import from engine.src.bytecode.optimizer { bcopt_gate_set, bcopt_p3_gate_set }
import from engine.src.vm.event_loop { el_run, el_gc_disable }
import from engine.src.runtime.jsstring { gc_str_min_limit_set_mb }
import from engine.src.runtime.realm {
    gc_min_threshold_set,
    gc_default_set,
    gc_growth_pct_set
}
import from engine.src.vm.vm { vm_ic_enable, vm_dump_pair_stats }
import from engine.src.builtins.process {
    process_do_exit,
    process_set_bootstrap_paths,
    process_set_exec_argv,
    process_set_input_type,
    process_set_eval_print,
    process_set_no_warnings,
    process_set_preserve_symlinks,
    process_set_preserve_symlinks_main,
    process_set_require_esm,
    process_set_title,
    process_set_no_deprecation,
    process_set_throw_deprecation,
    process_set_unhandled_rejections,
    process_unhandled_rejections_mode_valid,
    process_add_preload,
    process_set_expose_gc
}
import from engine.src.builtins.console { console_set_max_depth }
import from engine.src.builtins.env_file { env_file_load }
# _exit + getenv retained (adel dropped them) for HEAD's RC leak-trace startup hook.
import from engine.src.ffi.libc {
    stack_expand,
    ignore_sigpipe,
    _exit,
    getenv,
    fflush,
    chdir,
    write
}
import from engine.src.pm.cli { pm_try_dispatch }
import from engine.src.runtime.global {
    GlobalContext,
    global_context_create,
    init_global,
    env_gate_on,
    feature_gates_report
}

# ── Node-compatible CLI helpers ───────────────────────────────────────────────

"""True if `arg` is a CLI option token (starts with '-' but is not '-')."""
def _cli_is_option(arg: str) -> bool {
    if len(arg) < 2 {
        return False;
    }
    if arg[0] != "-" {
        return False;
    }
    # Bare "-" means read script from stdin (Node) — treat as positional.
    if arg == "-" {
        return False;
    }
    return True;
}

"""Unbuffered stderr line (print() is block-buffered on a pipe and _exit skips the flush)."""
def _cli_err(s: str) {
    write(2, s, len(s));
}

def _cli_is_uint(s: str) -> bool {
    if s == "" {
        return False;
    }
    i: int = 0;
    while i < len(s) {
        o: int = ord(s[i]);
        if o < 48 or o > 57 {
            return False;
        }
        i = i + 1;
    }
    return True;
}

"""True if this option consumes a following value token."""
def _cli_takes_value(opt: str) -> bool {
    if opt == "-e" or opt == "--eval" {
        return True;
    }
    if opt == "-p" or opt == "--print" {
        return True;
    }
    if opt == "-r" or opt == "--require" {
        return True;
    }
    if opt == "--import" {
        return True;
    }
    if opt == "--loader" or opt == "--experimental-loader" {
        return True;
    }
    if opt == "-C" or opt == "--conditions" {
        return True;
    }
    if opt == "--input-type" {
        return True;
    }
    if opt == "--title" {
        return True;
    }
    if opt == "--env-file" {
        return True;
    }
    if opt == "--cwd" {
        return True;
    }
    if opt == "--preload" {
        return True;
    }
    if opt == "--unhandled-rejections" {
        return True;
    }
    if opt == "--console-depth" {
        return True;
    }
    if opt == "-c" or opt == "--config" {
        return True;
    }
    return False;
}

"""Split `--flag=value` into [flag, value]; empty value means no '=' form."""
def _cli_split_eq(arg: str) -> list[str] {
    out: list[str] = [];
    i: int = 0;
    n: int = len(arg);
    # Long options only: --name=value (not -e=... which Node treats differently)
    if n >= 3 and arg[0] == "-" and arg[1] == "-" {
        while i < n {
            if arg[i] == "=" {
                out.append(arg[0:i]);
                out.append(arg[i + 1:]);
                return out;
            }
            i = i + 1;
        }
    }
    out.append(arg);
    out.append("");
    return out;
}

# ── ASTNodeType → label string ────────────────────────────────────────────────

def _nt_name(t: ASTNodeType) -> str {
    if t == ASTNodeType.Invalid {
        return "Invalid";
    } elif t == ASTNodeType.Program {
        return "Program";
    } elif t == ASTNodeType.BlockStatement {
        return "BlockStatement";
    } elif t == ASTNodeType.ExpressionStatement {
        return "ExpressionStatement";
    } elif t == ASTNodeType.EmptyStatement {
        return "EmptyStatement";
    } elif t == ASTNodeType.VariableDeclaration {
        return "VariableDeclaration";
    } elif t == ASTNodeType.VariableDeclarator {
        return "VariableDeclarator";
    } elif t == ASTNodeType.FunctionDeclaration {
        return "FunctionDeclaration";
    } elif t == ASTNodeType.ReturnStatement {
        return "ReturnStatement";
    } elif t == ASTNodeType.IfStatement {
        return "IfStatement";
    } elif t == ASTNodeType.WhileStatement {
        return "WhileStatement";
    } elif t == ASTNodeType.DoWhileStatement {
        return "DoWhileStatement";
    } elif t == ASTNodeType.ForStatement {
        return "ForStatement";
    } elif t == ASTNodeType.ForInStatement {
        return "ForInStatement";
    } elif t == ASTNodeType.ForOfStatement {
        return "ForOfStatement";
    } elif t == ASTNodeType.BreakStatement {
        return "BreakStatement";
    } elif t == ASTNodeType.ContinueStatement {
        return "ContinueStatement";
    } elif t == ASTNodeType.ThrowStatement {
        return "ThrowStatement";
    } elif t == ASTNodeType.TryStatement {
        return "TryStatement";
    } elif t == ASTNodeType.CatchClause {
        return "CatchClause";
    } elif t == ASTNodeType.SwitchStatement {
        return "SwitchStatement";
    } elif t == ASTNodeType.SwitchCase {
        return "SwitchCase";
    } elif t == ASTNodeType.ClassDeclaration {
        return "ClassDeclaration";
    } elif t == ASTNodeType.LabeledStatement {
        return "LabeledStatement";
    } elif t == ASTNodeType.DebuggerStatement {
        return "DebuggerStatement";
    } elif t == ASTNodeType.ImportDeclaration {
        return "ImportDeclaration";
    } elif t == ASTNodeType.ExportNamedDecl {
        return "ExportNamedDecl";
    } elif t == ASTNodeType.ExportDefaultDecl {
        return "ExportDefaultDecl";
    } elif t == ASTNodeType.ExportAllDecl {
        return "ExportAllDecl";
    } elif t == ASTNodeType.ImportSpecifier {
        return "ImportSpecifier";
    } elif t == ASTNodeType.ExportSpecifier {
        return "ExportSpecifier";
    } elif t == ASTNodeType.Identifier {
        return "Identifier";
    } elif t == ASTNodeType.Literal {
        return "Literal";
    } elif t == ASTNodeType.TemplateLiteral {
        return "TemplateLiteral";
    } elif t == ASTNodeType.TemplateElement {
        return "TemplateElement";
    } elif t == ASTNodeType.BinaryExpression {
        return "BinaryExpression";
    } elif t == ASTNodeType.UnaryExpression {
        return "UnaryExpression";
    } elif t == ASTNodeType.LogicalExpression {
        return "LogicalExpression";
    } elif t == ASTNodeType.AssignmentExpression {
        return "AssignmentExpression";
    } elif t == ASTNodeType.UpdateExpression {
        return "UpdateExpression";
    } elif t == ASTNodeType.ConditionalExpression {
        return "ConditionalExpression";
    } elif t == ASTNodeType.CallExpression {
        return "CallExpression";
    } elif t == ASTNodeType.NewExpression {
        return "NewExpression";
    } elif t == ASTNodeType.MemberExpression {
        return "MemberExpression";
    } elif t == ASTNodeType.OptionalChainExpr {
        return "OptionalChainExpr";
    } elif t == ASTNodeType.SpreadElement {
        return "SpreadElement";
    } elif t == ASTNodeType.ArrayExpression {
        return "ArrayExpression";
    } elif t == ASTNodeType.ObjectExpression {
        return "ObjectExpression";
    } elif t == ASTNodeType.Property {
        return "Property";
    } elif t == ASTNodeType.MethodDefinition {
        return "MethodDefinition";
    } elif t == ASTNodeType.FunctionExpression {
        return "FunctionExpression";
    } elif t == ASTNodeType.ArrowFunctionExpr {
        return "ArrowFunctionExpr";
    } elif t == ASTNodeType.ClassExpression {
        return "ClassExpression";
    } elif t == ASTNodeType.SequenceExpression {
        return "SequenceExpression";
    } elif t == ASTNodeType.AwaitExpression {
        return "AwaitExpression";
    } elif t == ASTNodeType.YieldExpression {
        return "YieldExpression";
    } elif t == ASTNodeType.TaggedTemplateExpr {
        return "TaggedTemplateExpr";
    } elif t == ASTNodeType.MetaProperty {
        return "MetaProperty";
    } elif t == ASTNodeType.AssignmentPattern {
        return "AssignmentPattern";
    } elif t == ASTNodeType.ObjectPattern {
        return "ObjectPattern";
    } elif t == ASTNodeType.ArrayPattern {
        return "ArrayPattern";
    } elif t == ASTNodeType.RestElement {
        return "RestElement";
    } else {
        return "Node(" + str(t) + ")";
    }
}

# ── AST printer ───────────────────────────────────────────────────────────────

"""Build an indentation prefix string."""
def _pad(depth: int) -> str {
    s: str = "";
    i: int = 0;
    while i < depth {
        s = s + "  ";
        i = i + 1;
    }
    return s;
}

"""Recursively print one AST node at the given indent depth."""
def _print_node(node_obj: ASTNode, depth: int) {
    p: str = _pad(depth);
    label: str = _nt_name(node_obj.ntype);

    # Collect inline annotations for the headline
    extras: str = "";
    if node_obj.name != "" {
        extras = extras + " name=" + node_obj.name;
    }
    if node_obj.value != "" {
        extras = extras + " value=" + node_obj.value;
    }
    if node_obj.operator != "" {
        extras = extras + " op=" + node_obj.operator;
    }
    if node_obj.kind != "" {
        extras = extras + " kind=" + node_obj.kind;
    }
    if node_obj.raw != "" and node_obj.raw != node_obj.value {
        extras = extras + " raw=" + node_obj.raw;
    }
    if node_obj.loc.line != 0 {
        extras = extras + " @" + str(node_obj.loc.line) + ":" + str(node_obj.loc.col);
    }
    print(p + label + extras);

    nd: int = depth + 1;

    # ── single-child sub-nodes ─────────────────────────────────────────────
    if node_obj.expression is not None {
        print(_pad(nd) + "expression:");
        _print_node(node_obj.expression, nd + 1);
    }
    if node_obj.id is not None {
        print(_pad(nd) + "id:");
        _print_node(node_obj.id, nd + 1);
    }
    if node_obj.body is not None {
        print(_pad(nd) + "body:");
        _print_node(node_obj.body, nd + 1);
    }
    if node_obj.cond_expr is not None {
        print(_pad(nd) + "test:");
        _print_node(node_obj.cond_expr, nd + 1);
    }
    if node_obj.consequent is not None {
        print(_pad(nd) + "consequent:");
        _print_node(node_obj.consequent, nd + 1);
    }
    if node_obj.alternate is not None {
        print(_pad(nd) + "alternate:");
        _print_node(node_obj.alternate, nd + 1);
    }
    if node_obj.left is not None {
        print(_pad(nd) + "left:");
        _print_node(node_obj.left, nd + 1);
    }
    if node_obj.right is not None {
        print(_pad(nd) + "right:");
        _print_node(node_obj.right, nd + 1);
    }
    if node_obj.argument is not None {
        print(_pad(nd) + "argument:");
        _print_node(node_obj.argument, nd + 1);
    }
    if node_obj.callee is not None {
        print(_pad(nd) + "callee:");
        _print_node(node_obj.callee, nd + 1);
    }
    if node_obj.object is not None {
        print(_pad(nd) + "object:");
        _print_node(node_obj.object, nd + 1);
    }
    if node_obj.property is not None {
        print(_pad(nd) + "property:");
        _print_node(node_obj.property, nd + 1);
    }
    if node_obj.key is not None {
        print(_pad(nd) + "key:");
        _print_node(node_obj.key, nd + 1);
    }
    if node_obj.init is not None {
        print(_pad(nd) + "init:");
        _print_node(node_obj.init, nd + 1);
    }
    if node_obj.update is not None {
        print(_pad(nd) + "update:");
        _print_node(node_obj.update, nd + 1);
    }
    if node_obj.handler is not None {
        print(_pad(nd) + "handler:");
        _print_node(node_obj.handler, nd + 1);
    }
    if node_obj.finalizer is not None {
        print(_pad(nd) + "finalizer:");
        _print_node(node_obj.finalizer, nd + 1);
    }
    if node_obj.param is not None {
        print(_pad(nd) + "param:");
        _print_node(node_obj.param, nd + 1);
    }
    if node_obj.discriminant is not None {
        print(_pad(nd) + "discriminant:");
        _print_node(node_obj.discriminant, nd + 1);
    }
    if node_obj.superclass is not None {
        print(_pad(nd) + "superClass:");
        _print_node(node_obj.superclass, nd + 1);
    }
    if node_obj.tag is not None {
        print(_pad(nd) + "tag:");
        _print_node(node_obj.tag, nd + 1);
    }
    if node_obj.quasi is not None {
        print(_pad(nd) + "quasi:");
        _print_node(node_obj.quasi, nd + 1);
    }
    if node_obj.source is not None {
        print(_pad(nd) + "source:");
        _print_node(node_obj.source, nd + 1);
    }

    # ── list children ──────────────────────────────────────────────────────
    if len(node_obj.children) > 0 {
        print(_pad(nd) + "body[" + str(len(node_obj.children)) + "]:");
        ci: int = 0;
        while ci < len(node_obj.children) {
            _print_node(node_obj.children[ci], nd + 1);
            ci = ci + 1;
        }
    }
    if len(node_obj.params) > 0 {
        print(_pad(nd) + "params[" + str(len(node_obj.params)) + "]:");
        pi_: int = 0;
        while pi_ < len(node_obj.params) {
            _print_node(node_obj.params[pi_], nd + 1);
            pi_ = pi_ + 1;
        }
    }
    if len(node_obj.arguments) > 0 {
        print(_pad(nd) + "arguments[" + str(len(node_obj.arguments)) + "]:");
        ai: int = 0;
        while ai < len(node_obj.arguments) {
            _print_node(node_obj.arguments[ai], nd + 1);
            ai = ai + 1;
        }
    }
    if len(node_obj.declarations) > 0 {
        print(_pad(nd) + "declarations[" + str(len(node_obj.declarations)) + "]:");
        di: int = 0;
        while di < len(node_obj.declarations) {
            _print_node(node_obj.declarations[di], nd + 1);
            di = di + 1;
        }
    }
    if len(node_obj.elements) > 0 {
        print(_pad(nd) + "elements[" + str(len(node_obj.elements)) + "]:");
        ei: int = 0;
        while ei < len(node_obj.elements) {
            _print_node(node_obj.elements[ei], nd + 1);
            ei = ei + 1;
        }
    }
    if len(node_obj.properties) > 0 {
        print(_pad(nd) + "properties[" + str(len(node_obj.properties)) + "]:");
        pri: int = 0;
        while pri < len(node_obj.properties) {
            _print_node(node_obj.properties[pri], nd + 1);
            pri = pri + 1;
        }
    }
    if len(node_obj.expressions) > 0 {
        print(_pad(nd) + "expressions[" + str(len(node_obj.expressions)) + "]:");
        exi: int = 0;
        while exi < len(node_obj.expressions) {
            _print_node(node_obj.expressions[exi], nd + 1);
            exi = exi + 1;
        }
    }
    if len(node_obj.quasis) > 0 {
        print(_pad(nd) + "quasis: " + str(node_obj.quasis));
    }
}

"""Print the full AST tree for a Program node."""
def print_ast(ast: ASTNode) {
    print("─── AST ─────────────────────────────────────────────────");
    _print_node(ast, 0);
    print("─────────────────────────────────────────────────────────");
}

# ── Bytecode printer ──────────────────────────────────────────────────────────

"""Print disassembly for every compiled function."""
def print_bytecode(fns: list[CompiledFunction]) {
    print("─── Bytecode ────────────────────────────────────────────");
    fi: int = 0;
    while fi < len(fns) {
        fn: CompiledFunction = fns[fi];
        print(disassemble(fn));
        reg_translate_fn(fn);
        rd: str = reg_disassemble(fn);
        if rd != "" {
            print(rd);
        }
        fi = fi + 1;
    }
    print("─────────────────────────────────────────────────────────");
}

# ── Entry point ───────────────────────────────────────────────────────────────

import sys;

with entry {
    stack_expand();
    ignore_sigpipe();

    # RC leak-trace mode: when JS_ENGINE_LEAKS_TEST is set (and the engine was
    # built with JAC_RC_DEBUG_CODEGEN so the trace is compiled in), turn on the
    # runtime retain/release/free logging. `make rc_leaks_test` sets both.
    if getenv("JS_ENGINE_LEAKS_TEST") != None {
        __rc_debug_enable();
    }
}

glob
     # ── bun-compatible package-manager commands (engine/src/pm) ──────────
     # `js_engine install|add|remove|update|…|pm|x|run` are handled there; any
     # other argv[1] falls through to the Node-style script runner below.
     # -2 = `run <file>`: drop the `run` token and run the file.
     argv_l: list[str] = [];
with entry {
    for a0 in sys.argv {
        argv_l.append(a0);
    }
    pm_rc: int = pm_try_dispatch(argv_l);
    if pm_rc >= 0 {
        fflush(0);
        _exit(pm_rc);
    }
    # -2: pm/cli.jac removed the `run` token itself; argv_l now names the file.

    # ── Node-compatible argv parse ────────────────────────────────────────
    # node [options] [ script.js | -e code | -p code ] [arguments]
    # Options may appear before the script; value-consuming flags eat the next
    # token. Everything after the script (or after --) is user argv.
    flag_ast: bool = False;
    flag_bc: bool = False;
    flag_norun: bool = False;
    flag_debug: bool = False;
    flag_eval: bool = False;
    flag_print: bool = False;
    flag_nogc: bool = False;  # the collector is on by default (event_loop._EL_GC_ENABLED, realm._GC_DEFAULT_ENABLED)
    flag_ic: bool = False;
    flag_gates: bool = False;
    js_file: str = "";
    source: str = "";
}

glob user_args: list[str] = [],
     exec_argv: list[str] = [];

with entry {
    input_type: str = "";
    no_warnings: bool = False;
}

glob
     # --loader values are recorded but not implemented; -r/--require/--import/--preload
     # go to process_add_preload and run before the entry point (event_loop.jac).
     loaders: list[str] = [],
     env_files: list[str] = [];

with entry {
    flag_if_present: bool = False;

    argc: int = len(argv_l);
    if argc < 2 {
        print("Usage: js_engine [options] <script.js> [args...]");
        print("       js_engine [options] -e|--eval <code> [args...]");
        fflush(0);  # print() is block-buffered on a pipe; _exit skips the flush
        _exit(1);
    }

    i: int = 1;
    end_of_opts: bool = False;
    while i < argc {
        arg: str = argv_l[i];

        if end_of_opts {
            if js_file == "" and not flag_eval {
                js_file = arg;
            } else {
                user_args.append(arg);
            }
            i = i + 1;
            continue;
        }

        if arg == "--" {
            end_of_opts = True;
            i = i + 1;
            continue;
        }

        if not _cli_is_option(arg) {
            # First positional = script (unless -e/-p already set).
            if js_file == "" and not flag_eval {
                js_file = arg;
                # After the script, remaining tokens are always user args
                # (Node stops option parsing after the script path).
                end_of_opts = True;
            } else {
                user_args.append(arg);
            }
            i = i + 1;
            continue;
        }

        # Option token — support --flag=value
        parts: list[str] = _cli_split_eq(arg);
        opt: str = parts[0];
        inline_val: str = parts[1];
        has_inline: bool = inline_val != ""
            or (len(arg) > len(opt) and arg[len(opt)] == "=");

        # Engine-debug flags (js_engine specific; also recorded in execArgv)
        if opt == "--ast" {
            flag_ast = True;
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        if opt == "--bc" {
            flag_bc = True;
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        if opt == "--norun" {
            flag_norun = True;
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        # Print the effective feature gates (NAME=0|1, after the same init a
        # script run does) and exit; pinned by tests/qa/cli/test_feature_gate_defaults.sh.
        if opt == "--feature-gates" {
            flag_gates = True;
            i = i + 1;
            continue;
        }
        if opt == "--debug" {
            flag_debug = True;
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        if opt == "--gc" {
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        if opt == "--nogc" or opt == "--no-gc" {
            flag_nogc = True;
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        if opt == "--ic" {
            # Phase 4 monomorphic property IC — off by default; validate in isolation.
            flag_ic = True;
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }

        # Runtime flags shared with bun's CLI (engine/src/pm/help/root.txt)
        if opt == "--smol" {
            # less memory: collect four times as often and let the heap only
            # double between collections (explicit JAC_GC_MIN_THRESHOLD /
            # JAC_GC_GROWTH, applied below, still win)
            gc_min_threshold_set(2500);
            gc_growth_pct_set(100);
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        if opt == "--expose-gc" {
            process_set_expose_gc(True);
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        if opt == "--no-deprecation" {
            process_set_no_deprecation(True);
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        if opt == "--throw-deprecation" {
            process_set_throw_deprecation(True);
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        if opt == "--if-present" {
            flag_if_present = True;
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }
        # Accepted without further effect here: Buffer.allocUnsafe is always zero-filled;
        # --silent and -b/--bun only concern package.json scripts (pm/cli.jac).
        if opt == "--zero-fill-buffers"
            or opt == "--silent"
            or opt == "-b"
            or opt == "--bun" {
            exec_argv.append(opt);
            i = i + 1;
            continue;
        }

        # -e / --eval / -p / --print
        if opt == "-e" or opt == "--eval" or opt == "-p" or opt == "--print" {
            code: str = "";
            if has_inline {
                code = inline_val;
                exec_argv.append(opt + "=" + inline_val);
            } else {
                if i + 1 >= argc {
                    print("Error: " + opt + " requires an argument");
                    _exit(9);
                }
                code = argv_l[i + 1];
                exec_argv.append(opt);
                exec_argv.append(code);
                i = i + 1;
            }
            flag_eval = True;
            if opt == "-p" or opt == "--print" {
                flag_print = True;
            }
            source = code;
            js_file = "<eval>";
            i = i + 1;
            continue;
        }

        # --input-type[=]module|commonjs
        if opt == "--input-type" {
            val: str = "";
            if has_inline {
                val = inline_val;
                exec_argv.append(opt + "=" + inline_val);
            } else {
                if i + 1 >= argc {
                    print("Error: --input-type requires an argument");
                    _exit(9);
                }
                val = argv_l[i + 1];
                exec_argv.append(opt);
                exec_argv.append(val);
                i = i + 1;
            }
            if val != "module" and val != "commonjs" {
                print("Error: invalid value for --input-type: " + val);
                _exit(9);
            }
            input_type = val;
            i = i + 1;
            continue;
        }

        # Value-consuming flags we record but don't fully implement yet
        if _cli_takes_value(opt) {
            val2: str = "";
            if has_inline {
                val2 = inline_val;
                exec_argv.append(opt + "=" + inline_val);
            } else {
                if i + 1 >= argc {
                    print("Error: " + opt + " requires an argument");
                    _exit(9);
                }
                val2 = argv_l[i + 1];
                exec_argv.append(opt);
                exec_argv.append(val2);
                i = i + 1;
            }
            if opt == "-r"
                or opt == "--require"
                or opt == "--import"
                or opt == "--preload" {
                process_add_preload(val2);
            } elif opt == "--loader" or opt == "--experimental-loader" {
                loaders.append(val2);
            } elif opt == "--title" {
                process_set_title(val2);
            } elif opt == "--env-file" {
                env_files.append(val2);
            } elif opt == "--cwd" {
                if chdir(val2) != 0 {
                    _cli_err("error: --cwd: cannot change to \"" + val2 + "\"\n");
                    _exit(1);
                }
            } elif opt == "--unhandled-rejections" {
                if not process_unhandled_rejections_mode_valid(val2) {
                    _cli_err(
                        "js_engine: invalid value for --unhandled-rejections: "
                            + val2
                            + "\n"
                    );
                    _exit(9);
                }
                process_set_unhandled_rejections(val2);
            } elif opt == "--console-depth" {
                if not _cli_is_uint(val2) {
                    _cli_err(
                        "js_engine: invalid value for --console-depth: " + val2 + "\n"
                    );
                    _exit(9);
                }
                console_set_max_depth(int(val2));
            }
            # -c/--config only concerns package-manager commands (pm/cli.jac)
            i = i + 1;
            continue;
        }

        # Boolean / passthrough flags (Node-forward-compat)
        if has_inline {
            exec_argv.append(opt + "=" + inline_val);
        } else {
            exec_argv.append(opt);
        }
        if opt == "--no-warnings" {
            no_warnings = True;
        }
        if opt == "--preserve-symlinks" {
            process_set_preserve_symlinks(True);
        }
        if opt == "--preserve-symlinks-main" {
            process_set_preserve_symlinks_main(True);
        }
        if (
            opt == "--no-experimental-require-module" or opt == "--no-require-module"
        ) {
            process_set_require_esm(False);
        }
        if (opt == "--experimental-require-module" or opt == "--require-module") {
            process_set_require_esm(True);
        }
        i = i + 1;
    }

    # --env-file (Node semantics): variables already in the environment win; a
    # missing file is fatal with exit 9, like node.
    for ef in env_files {
        if env_file_load(ef) < 0 {
            _cli_err("js_engine: " + ef + ": not found\n");
            _exit(9);
        }
    }

    if flag_nogc {
        el_gc_disable();
        gc_default_set(False);
    }
    # JAC_GC_MIN_THRESHOLD: tune GC collection frequency (allocations between
    # collections before adaptive growth). Higher = collect less often (lower
    # CPU / higher peak). Set before the realm is built so realm_new picks it up.
    gc_min_env: str = getenv("JAC_GC_MIN_THRESHOLD");
    if gc_min_env != None {
        gc_min_threshold_set(int(gc_min_env));
    }
    gc_growth_env: str = getenv("JAC_GC_GROWTH");
    if gc_growth_env != None {
        gc_growth_pct_set(int(gc_growth_env));
    }
    gc_str_env: str = getenv("JAC_GC_STR_MB");
    if gc_str_env != None {
        gc_str_min_limit_set_mb(int(gc_str_env));
    }
    if flag_ic {
        vm_ic_enable();
    }
    if flag_gates {
        fg_ctx: GlobalContext = global_context_create();
        init_global(fg_ctx);
        print(feature_gates_report());
        fflush(0);
        _exit(0);
    }
    process_set_exec_argv(exec_argv);
    process_set_input_type(input_type);
    process_set_eval_print(flag_print);
    process_set_no_warnings(no_warnings);

    if not flag_eval {
        if js_file == "" {
            _cli_err("Error: no script file specified\n");
            _exit(1);
        }
        try {
            source = open(js_file).read();
        } except Exception {
            if flag_if_present {
                _exit(0);
            }  # --if-present: a missing entrypoint is not an error
            _cli_err("Error: file not found: " + js_file + "\n");
            _exit(1);
        }
    }
    if flag_debug {
        print("Running: " + js_file + "  (" + str(len(source)) + " bytes)");
    }

    # preload_requires / preload_imports / loaders are recorded for later waves
    # (module.registerHooks / --require / --loader chaining). Consuming their
    # value tokens is what unblocks spawn-based es-module tests today.

    # ── Parse + Compile (only needed for --ast / --bc / --norun debug output) ──
    # el_run() does its own parse+compile internally for execution, so we skip
    # this step entirely for normal runs to avoid doubling parse+compile memory.
    if flag_ast or flag_bc or flag_norun {
        # This debug compile runs BEFORE el_run/init_global (which normally
        # wires the lever), so honor JS_BCOPT here too — otherwise `--bc`
        # always shows optimized bytecode and lever A/B dumps mislead.
        bcopt_gate_set(env_gate_on("JS_BCOPT"));
        bcopt_p3_gate_set(env_gate_on("JS_BCOPT_P3"));
        ast: ASTNode = parse(source, False, True);  # explicit args (native default-fill is unreliable)

        if flag_ast {
            print_ast(ast);
        }

        c = make_compiler();
        c.source_text = source;
        top_fn: CompiledFunction = c.compile_program(ast);

        if flag_bc {
            all_disp: list[CompiledFunction] = [];
            all_disp.append(top_fn);
            fni: int = 0;
            while fni < len(c.all_fns) {
                all_disp.append(c.all_fns[fni]);
                fni = fni + 1;
            }
            print_bytecode(all_disp);
        }
    }

    # ── Execute ────────────────────────────────────────────────────────────
    if not flag_norun {
        process_set_bootstrap_paths(sys.argv[0]);
        status: int = el_run(source, js_file, user_args);
        vm_dump_pair_stats();  # no-op unless JS_PAIR_STATS=1
        # Route success through process_do_exit too: it flushes NAPI
        # external-buffer finalizers (and stdio) before _exit — a status-0
        # fall-through would skip them.
        process_do_exit(status);
    }
}

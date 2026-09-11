import from jaclang.compiler.jc_materialize {
    Materialization, jc_mz_finish,
    jc_mz_run,
    jc_mz_shapes3
}
import from jaclang.compiler.frontend.result {
    FRONTEND_ABI, EarlyPassResult, FrontendResult
}

import from jaclang.compiler.frontend.parser.parser { parse_program }
import from jaclang.compiler.frontend.unitree { GraphExpr, UniNode }
import from jaclang.compiler.frontend.roles { AccessorsRole, BodyRole, SpecRole }
import from jaclang.compiler.frontend.constant { CodeContext }
import from jaclang.compiler.frontend.unitree { Import }
import from jaclang.compiler.passes.ast_validation_pass { ASTValidationPass }
import from jaclang.compiler.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.passes.decl_impl_match_pass { DeclImplMatchPass }
import from jaclang.compiler.passes.transform { Transform }
import from jaclang.compiler.passes.annex_weave { merge_annex_into }

obj JcSource {
    has source: str, path: str;
}

obj JcRequest {
    has source: str,
        path: str,
        early_context: int,
        annexes: list[JcSource] = [];
}

def:pub jc_probe -> int {
    return 44061;
}

def:pub jc_result_abi -> int {
    return FRONTEND_ABI;
}

def:pub jc_request(src: own str, path: own str, context: int) -> own JcRequest {
    return JcRequest(source=src, path=path, early_context=context);
}

def:pub jc_annex(request: &mut JcRequest, src: own str, path: own str) -> int {
    request.annexes.append(JcSource(source=src, path=path));
    return 0;
}

def:pub jc_discard(request: own JcRequest) {
    # Consuming the request also reclaims any partially prepared annex inputs.
}

def _record_pass(result: FrontendResult, name: str, pass_result: Transform) {
    result.passes.append(EarlyPassResult(
        name=name,
        errors_had=pass_result.errors_had,
        warnings_had=pass_result.warnings_had,
        time_taken=pass_result.time_taken
    ));
}

def _parse_source(source: str, path: str) -> FrontendResult {
    (mod, p_errs, p_diags, comments, lex_diags, lex_errs) = parse_program(source, path);
    return FrontendResult(
        module=mod,
        parse_errors=p_errs,
        lex_errors=lex_errs,
        diagnostics=p_diags,
        lex_diagnostics=lex_diags,
        comments=comments
    );
}

def _finish_unit(result: FrontendResult, context: int) -> int {
    mod = result.module;
    if context != 0
        and not result.has_errors()
        and not mod.get_all_sub_nodes(GraphExpr) {
        if context == 2 {
            mod.set_code_context(CodeContext.CLIENT);
        } elif context == 3 {
            mod.set_code_context(CodeContext.NATIVE);
        }
        validation = ASTValidationPass(ir_in=mod);
        _record_pass(result, "ASTValidationPass", validation);
        has_absorb = False;
        for imp in mod.get_all_sub_nodes(Import) {
            if imp.is_absorb {
                has_absorb = True;
                break;
            }
        }
        if not has_absorb {
            symbols = SymTabBuildPass(ir_in=mod);
            _record_pass(result, "SymTabBuildPass", symbols);
            if not validation.errors_had and not symbols.errors_had {
                binding = DeclImplMatchPass(ir_in=mod);
                _record_pass(result, "DeclImplMatchPass", binding);
            }
        }
    }
    # Materialize one connected result, including all pass diagnostics.
    # The returned Python reference owns the transport after the arena retires.
    materialization = Materialization();
    out = jc_mz_run(materialization, id(result));
    if out != 0 {
        _apply_shapes(result, materialization);
    }
    return jc_mz_finish(materialization, out);
}

def _run_in_region(request: &JcRequest) -> int {
    out = 0;
    r = Region();
    in r {
        result = _parse_source(request.source, request.path);
        if not result.has_errors() {
            for annex in request.annexes {
                parsed = _parse_source(annex.source, annex.path);
                result.annexes.append(parsed);
                if not parsed.has_errors() {
                    merge_annex_into(result.module, parsed.module);
                }
            }
        }
        out = _finish_unit(result, request.early_context);
    }
    return out;
}

def:pub jc_run(request: own JcRequest) -> int {
    return _run_in_region(&request);
}

def _shape_code(s: (str | None)) -> int {
    if s is None {
        return 0;
    }
    if s == "one" {
        return 2;
    }
    if s == "many" {
        return 3;
    }
    return 1;
}

def _packed_shapes(nd: UniNode) -> int {
    shapes = nd._role_shapes;
    if shapes is None {
        return 0;
    }
    b = _shape_code(shapes.get(BodyRole));
    sp = _shape_code(shapes.get(SpecRole));
    a = _shape_code(shapes.get(AccessorsRole));
    return b | (sp << 4) | (a << 8);
}

def _apply_shapes(result: FrontendResult, materialization: Materialization) {
    stack: list[UniNode] = [result.module];
    for annex in result.annexes {
        stack.append(annex.module);
    }
    seen: set[int] = set();
    while stack {
        cur = stack.pop();
        if id(cur) in seen {
            continue;
        }
        seen.add(id(cur));
        sc = _packed_shapes(cur);
        if sc != 0 {
            jc_mz_shapes3(materialization, id(cur), sc);
        }
        for k in cur._children() {
            stack.append(k);
        }
    }
}

def:pub jc_rc_debug(v: int) -> int {
    if v != 0 {
        __rc_debug_enable();
    } else {
        __rc_debug_disable();
    }
    return 0;
}

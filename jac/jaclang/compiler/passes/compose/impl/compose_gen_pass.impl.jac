import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.compose.compose_model { ComposeModule }
import from jaclang.compiler.passes.ecmascript.intent.collector { IntentCollector }
import from jaclang.compiler.passes.ecmascript.intent.session {
    IntentSession,
    SkipExistingPolicy
}
import from jaclang.compiler.passes.ecmascript.intent.detection {
    COMPOSE_COMPONENT_TYPES,
    unwrap_ability_body
}
import from jaclang.compiler.passes.compose.compose_leaf_converter {
    ComposeLeafConverter
}
import from jaclang.compiler.passes.compose.compose_intent_adapter {
    ComposeIntentAdapter
}
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }
import from jaclang.compiler.passes.compose.compose_view_builder { ComposeViewBuilder }
import from jaclang.compiler.passes.compose.kotlin_ast { KtLiteral }
import from jaclang.compiler.passes.ecmascript.intent.model { IntentParam }
import from jaclang.compiler.passes.ecmascript.intent.detection {
    component_name_from_ability,
    COMPOSE_COMPONENT_TYPES
}
import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }

impl ComposeGenPass.before_pass -> None {
    self.reactive_vars = set();
    self.lowerer = JacToKotlin(reactive_vars=self.reactive_vars);
    self.view_builder = ComposeViewBuilder(lowerer=self.lowerer);
    self.collector = IntentCollector();
    self.collector.link_module(self.model.intent);
    self.converter = ComposeLeafConverter(
        lowerer=self.lowerer,
        null_expr=KtLiteral(value=None),
        fallback_expr=KtLiteral(value=None),
        reactive_vars=self.reactive_vars
    );
    self.intent_session = IntentSession(
        collector=self.collector,
        adapter=ComposeIntentAdapter(collector=self.collector),
        converter=self.converter,
        pass_ref=self,
        component_types=COMPOSE_COMPONENT_TYPES,
        strict_arch_has=False,
        use_arch_has_dedup=True,
        skip_existing_policy=SkipExistingPolicy.MODULE,
        reactive_vars=self.reactive_vars
    );
}

impl ComposeGenPass.after_pass -> None {
    for diag in self.lowerer.diagnostics {
        self.model.intent.add_diagnostic(diag);
    }
    for diag in self.view_builder.diagnostics {
        self.model.intent.add_diagnostic(diag);
    }
}

impl ComposeGenPass._session -> IntentSession {
    assert self.intent_session is not None , "intent_session is initialized in before_pass";
    return self.intent_session;
}

def _jac_type_text(type_expr: (uni.Expr | None)) -> str {
    if type_expr is None {
        return "";
    }
    if hasattr(type_expr, 'unparse') {
        return type_expr.unparse();
    }
    if isinstance(type_expr, uni.Name) {
        return type_expr.value;
    }
    return str(type_expr);
}

def _intent_params_from_signature(
    sig: uni.FuncSignature, lowerer: JacToKotlin
) -> list[IntentParam] {
    out: list[IntentParam] = [];
    for p in (sig.get_parameters() if sig else []) {
        if not isinstance(p, uni.ParamVar) {
            continue;
        }
        pname = p.name.sym_name if p.name else "";
        if not pname {
            continue;
        }
        jac_type = "";
        if p.type_tag and p.type_tag.tag {
            jac_type = _jac_type_text(p.type_tag.tag);
        }
        default_kt: (str | None) = None;
        if p.value {
            kt_val = lowerer.convert_expr(p.value);
            if kt_val {
                default_kt = kt_to_source(kt_val);
            }
        }
        out.append(IntentParam(name=pname, jac_type=jac_type, default_kt=default_kt));
    }
    return out;
}

impl ComposeGenPass.enter_ability(nd: uni.Ability) -> None {
    self._session().enter_ability(nd);
    name = component_name_from_ability(nd, COMPOSE_COMPONENT_TYPES);
    if name is not None and isinstance(nd.signature, uni.FuncSignature) {
        comp = self.model.intent.ensure_component(name);
        comp.params = _intent_params_from_signature(nd.signature, self.lowerer);
    }
}

impl ComposeGenPass.exit_arch_has(nd: uni.ArchHas) -> None {
    scan = self._session().scan_arch_has(nd);
    if scan is not None {
        self._session().adapter.apply_arch_has_scan(nd, scan);
    }
}

impl ComposeGenPass._sync_lowerer_reactive_vars -> None {
    names = self.collector.existing_reactive_names();
    self.reactive_vars = names;
    self._session().reactive_vars = names;
    self.collector.reactive_vars = names;
    self.lowerer.reactive_vars = names;
    if self.converter is not None {
        self.converter.reactive_vars = names;
    }
}

impl ComposeGenPass.exit_assignment(nd: uni.Assignment) -> None {
    update = self._session().scan_state_update(nd);
    if update is not None {
        self._session().adapter.lower_state_update(nd, update);
    }
}

impl ComposeGenPass.exit_ability(nd: uni.Ability) -> None {
    if isinstance(nd.signature, uni.EventSignature) and nd.in_client_context() {
        self._session().record_and_lower_effect(nd);
    }

    inner = unwrap_ability_body(nd);
    if inner {
        self._sync_lowerer_reactive_vars();
        comp_name = self.model.intent.current;
        if comp_name is not None {
            view = self.view_builder.lower_component_view(inner);
            if view is not None {
                self.model.compose_views[comp_name] = view;
            }
        }
    }

    self._session().pop_ability_scope();
}

impl ComposeGenPass.exit_jsx_element(nd: uni.JsxElement) -> None {
    return;
}

glob _KOTLIN_IMPORT_ROOTS: set[str] = {
         "androidx",
         "android",
         "kotlin",
         "kotlinx",
         "java",
         "javax",
         "com",
         "org",
         "io",
         "dev",
         "net"
     };

def _kotlin_import_lines(nd: uni.Import) -> list[str] {
    fl = nd.from_loc;
    if fl is not None {
        if getattr(fl, "level", 0) and fl.level > 0 {
            return [];
        }
        dot = fl.dot_path_str or "";
        if "." not in dot or dot.split(".")[0] not in _KOTLIN_IMPORT_ROOTS {
            return [];
        }
        lines: list[str] = [];
        for it in (nd.items or []) {
            if isinstance(it, uni.ModuleItem) {
                nm = it.name?.value or str(it.name);
                if not nm {
                    continue;
                }

                if it.alias is not None and getattr(it.alias, "value", "") {
                    lines.append(f"{dot}.{nm} as {it.alias.value}");
                } else {
                    lines.append(f"{dot}.{nm}");
                }
            }
        }
        if not lines {
            lines.append(f"{dot}.*");
        }
        return lines;
    }

    out: list[str] = [];
    for it in (nd.items or []) {
        if isinstance(it, uni.ModulePath) {
            if getattr(it, "level", 0) and it.level > 0 {
                continue;
            }
            dot = it.dot_path_str or "";
            if "." in dot and dot.split(".")[0] in _KOTLIN_IMPORT_ROOTS {
                out.append(dot);
            }
        }
    }
    return out;
}

impl ComposeGenPass.exit_import(nd: uni.Import) -> None {
    if not nd.in_client_context() {
        return;
    }
    for line in _kotlin_import_lines(nd) {
        self.model.add_kotlin_import(line);
    }
}

impl run_compose_gen_pass(
    mod: uni.Module, prog: any = None, into: (ComposeModule | None) = None
) -> ComposeModule {
    pass_inst = ComposeGenPass(ir_in=mod, prog=prog);
    if into is not None {
        pass_inst.model = into;
        pass_inst.collector.link_module(into.intent);
    }
    pass_inst.transform(mod);
    return pass_inst.model;
}

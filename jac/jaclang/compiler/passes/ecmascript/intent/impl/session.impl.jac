import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.intent.semantics {
    IntentLeaf,
    StateUpdate
}

impl IntentSession._sync_converter_reactive_vars -> None {
    self.converter.reactive_vars = self.reactive_vars;
}

impl IntentSession.enter_ability(nd: uni.Ability) -> None {
    import from jaclang.compiler.passes.ecmascript.intent.detection {
        component_name_from_ability,
        screen_meta_for_component
    }
    self.reactive_vars_stack.append(self.reactive_vars);
    self.reactive_vars = set(self.reactive_vars);
    self.collector.reactive_vars = self.reactive_vars;
    self._sync_converter_reactive_vars();
    name = component_name_from_ability(nd, self.component_types);
    if name is not None and isinstance(nd.signature, uni.FuncSignature) {
        self.collector.enter_component(name);
        rt = nd.signature.return_type;
        if rt is not None {
            (is_screen, route_path) = screen_meta_for_component(name, rt);
            if is_screen {
                self.collector.mark_screen(name, True, route_path);
            }
        }
    }
}

impl IntentSession.pop_ability_scope -> None {
    if self.reactive_vars_stack {
        self.reactive_vars = self.reactive_vars_stack.pop();
        self.collector.reactive_vars = self.reactive_vars;
        self._sync_converter_reactive_vars();
    } else {
        self.reactive_vars = set();
        self.collector.reactive_vars = self.reactive_vars;
        self.converter.reactive_vars = set();
    }
}

impl IntentSession.arch_has_skip_existing -> set[str] {
    if self.skip_existing_policy == SkipExistingPolicy.MODULE {
        return self.collector.existing_reactive_names();
    }
    return set();
}

impl IntentSession.scan_arch_has(nd: uni.ArchHas) -> (ArchHasScanResult | None) {
    import from jaclang.compiler.passes.ecmascript.intent.detection {
        arch_has_applicable,
        scan_arch_has
    }
    if self.use_arch_has_dedup and id(nd) in self._recorded_arch_has {
        return None;
    }
    if not arch_has_applicable(nd, strict_client=self.strict_arch_has) {
        return None;
    }
    scan = scan_arch_has(
        nd, skip_existing=self.arch_has_skip_existing(), conv=self.converter
    );
    if self.use_arch_has_dedup {
        self._recorded_arch_has.add(id(nd));
    }
    return scan;
}

impl IntentSession.scan_state_update(nd: uni.Assignment) -> (StateUpdate | None) {
    import from jaclang.compiler.passes.ecmascript.intent.detection {
        scan_state_update
    }
    return scan_state_update(
        nd,
        self.converter,
        convert_value=lambda (v: uni.Expr | uni.YieldExpr) { self.converter.convert_assignment_value(
            nd, v
        ); }
    );
}

impl IntentSession.lower_state_update(
    nd: uni.Assignment, update: StateUpdate
) -> (IntentLeaf | None) {
    return self.adapter.lower_state_update(nd, update);
}

impl IntentSession.record_and_lower_effect(nd: uni.Ability) -> list[IntentLeaf] {
    import from jaclang.compiler.passes.ecmascript.intent.detection {
        unwrap_ability_body,
        effect_from_ability
    }
    inner = unwrap_ability_body(nd);
    body_stmts: list[IntentLeaf] = [];
    if inner {
        body_stmts = self.converter.convert_stmts(inner);
    }
    deps: list[IntentLeaf] = [];
    if self.pass_ref is not None and hasattr(self.pass_ref, 'effect_deps') {
        deps = self.pass_ref.effect_deps(nd);
    }
    effect = effect_from_ability(nd, body_stmts, deps);
    return self.adapter.lower_effect(nd, effect);
}

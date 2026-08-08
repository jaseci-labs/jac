import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.ecmascript.intent.semantics {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }
import from jaclang.compiler.passes.ecmascript.intent.model { IntentModule }

obj IntentCollector {
    has _own_module: (IntentModule | None) = None,
        _linked_module: (IntentModule | None) = None,
        reactive_vars: set[str] = set();

    def init(module: (IntentModule | None) = None) {
        if module is not None {
            self._linked_module = module;
        }
    }

    def link_module(module: IntentModule) {
        self._linked_module = module;
    }

    def module -> IntentModule {
        if self._linked_module is not None {
            return self._linked_module;
        }
        if self._own_module is None {
            self._own_module = IntentModule();
        }
        self._linked_module = self._own_module;
        return self._linked_module;
    }

    def enter_component(name: str) {
        m = self.module();
        m.current = name;
        m.ensure_component(name);
    }

    def mark_screen(name: str, is_screen: bool = True, route_path: (str | None) = "/") {
        comp = self.module().ensure_component(name);
        comp.is_screen = is_screen;
        if route_path {
            comp.route_path = route_path;
        }
    }

    def existing_reactive_names -> set[str] {
        comp = self.module().current_component();
        names: set[str] = set();
        for s in comp.state {
            names.add(s.name);
        }
        for r in comp.refs {
            names.add(r.name);
        }
        return names;
    }

    def record_state_field(s: StateField) {
        self.module().current_component().state.append(s);
        self.reactive_vars.add(s.name);
    }

    def record_ref_field(r: RefField) {
        self.module().current_component().refs.append(r);
        self.reactive_vars.add(r.name);
    }

    def record_state_update(u: StateUpdate) {
        self.module().current_component().updates.append(u);
    }

    def record_effect(e: Effect) {
        self.module().current_component().effects.append(e);
    }

    def record_async_boundary(a: AsyncBoundary) {
        self.module().current_component().asyncs.append(a);
    }

    def record_view(view: ViewElement) {
        self.module().current_component().view = view;
    }
}

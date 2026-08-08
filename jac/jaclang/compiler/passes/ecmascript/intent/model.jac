import from jaclang.compiler.passes.ecmascript.intent.semantics {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }

obj IntentRoute {
    has path: str = "/",
        screen_name: str = "HomeScreen",
        component: (str | None) = None;
}

obj IntentParam {
    has name: str = "",
        jac_type: str = "",
        default_kt: (str | None) = None;
}

obj IntentComponent {
    has name: str = "",
        params: list[IntentParam] = [],
        state: list[StateField] = [],
        refs: list[RefField] = [],
        effects: list[Effect] = [],
        asyncs: list[AsyncBoundary] = [],
        updates: list[StateUpdate] = [],
        view: (ViewElement | None) = None,
        is_screen: bool = False,
        route_path: (str | None) = None;
}

obj IntentModule {
    has components: dict[str, IntentComponent] = {},
        current: (str | None) = None,
        routes: list[IntentRoute] = [],
        imports: list[str] = [],
        package_name: str = "dev.jac.generated",
        app_name: str = "Jac App",
        backend_url: str = "",
        diagnostics: list[str] = [],
        interop_manifest: any = None;

    def add_import(imp: str) {
        if imp not in self.imports {
            self.imports.append(imp);
        }
    }

    def ensure_component(name: str) -> IntentComponent {
        if name not in self.components {
            self.components[name] = IntentComponent(name=name);
        }
        return self.components[name];
    }

    def current_component -> IntentComponent {
        cname = self.current or "__root__";
        return self.ensure_component(cname);
    }

    def add_diagnostic(msg: str) {
        self.diagnostics.append(msg);
    }

    def merge_from(other: IntentModule) -> None {
        if other is None or other is self {
            return;
        }
        for (name, comp) in other.components.items() {
            dst = self.ensure_component(name);
            if comp.view is not None {
                dst.view = comp.view;
            }
            dst.state.extend(comp.state);
            dst.refs.extend(comp.refs);
            dst.effects.extend(comp.effects);
            dst.asyncs.extend(comp.asyncs);
            dst.updates.extend(comp.updates);
            if comp.is_screen {
                dst.is_screen = True;
            }
            if comp.route_path {
                dst.route_path = comp.route_path;
            }
            if comp.params {
                dst.params = list(comp.params);
            }
        }
        for imp in other.imports {
            self.add_import(imp);
        }
        for diag in other.diagnostics {
            self.add_diagnostic(diag);
        }
    }
}

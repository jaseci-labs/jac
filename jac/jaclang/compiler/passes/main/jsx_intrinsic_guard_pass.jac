import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.diagnostics { E1105 }
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.project.client_kind {
    mobui_module_exempt,
    resolve_client_kind_context
}

glob _GENERIC_SUGGESTION: str = "an @jac/mobui component",
     _tag_suggestions: (dict[str, str] | None) = None;

def _suggestion_for(tag: str) -> str {
    global _tag_suggestions;
    if _tag_suggestions is None {
        try {
            import from jaclang.runtimelib.client.targets.react_native.html_tag_map {
                rn_tag_suggestions
            }
            _tag_suggestions = rn_tag_suggestions();
        } except ImportError {
            _tag_suggestions = {};
        }
    }
    return _tag_suggestions.get(tag, _GENERIC_SUGGESTION);
}

class JsxIntrinsicGuardPass(UniPass) {
    def before_pass(self: JsxIntrinsicGuardPass) {
        opts = self.prog._compile_options;
        (kind, proj_root) = resolve_client_kind_context(
            self.ir_in.loc.mod_path, opts.project_kind, opts.project_root
        );
        self._enforced_root: (str | None) = proj_root if kind == "mobui" else None;
        self._exempt_paths: dict[str, bool] = {};
    }

    def enter_module(self: JsxIntrinsicGuardPass, nd: uni.Module) {
        if self._enforced_root is None {
            self.prune();
        }
    }

    def enter_jsx_element(self: JsxIntrinsicGuardPass, nd: uni.JsxElement) -> None {
        if isinstance(nd.parent, uni.JsxElement) {
            return;
        }
        self._check_element(nd);
    }

    def _check_element(self: JsxIntrinsicGuardPass, el: uni.JsxElement) {
        if (
            self._enforced_root is not None
            and not self._is_exempt(el.loc.mod_path)
            and el.name is not None
            and el.name.parts
        ) {
            first = el.name.parts[0];
            tag = first.value or "" if isinstance(first, (uni.Name, uni.Token)) else "";
            if tag and tag[0].islower() and not self._resolves_in_scope(el, first) {
                self.emit(
                    E1105, node_override=first, tag=tag, suggestion=_suggestion_for(tag)
                );
            }
        }
        for child in (el.children or []) {
            if isinstance(child, uni.JsxElement) {
                self._check_element(child);
            }
        }
    }

    def _resolves_in_scope(
        self: JsxIntrinsicGuardPass, el: uni.JsxElement, first: uni.UniNode
    ) -> bool {
        if not isinstance(first, uni.Name) or not el.sym_tab {
            return False;
        }
        name_chain = [
            p
            for p in el.name.parts
            if isinstance(p, uni.Name)
        ];
        el.sym_tab.chain_use_lookup(name_chain);
        return first.sym is not None;
    }

    def _is_exempt(self: JsxIntrinsicGuardPass, mod_path: str) -> bool {
        if mod_path not in self._exempt_paths {
            self._exempt_paths[mod_path] = mobui_module_exempt(
                mod_path, self._enforced_root
            );
        }
        return self._exempt_paths[mod_path];
    }
}

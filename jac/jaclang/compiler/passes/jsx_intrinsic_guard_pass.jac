import from jaclang.compiler.frontend.unitree {
    JsxElement,
    Module,
    Name,
    Token,
    UniNode
}
import from jaclang.compiler.frontend.diagnostics { E1105 }
import from jaclang.compiler.passes.uni_pass { UniPass }
import from jaclang.runtime.osp_kernel { osp_skip_rest }
import from jaclang.project.mobui_scope { mobui_module_exempt }

glob _GENERIC_SUGGESTION: str = "an @jac/mobui component",
     _tag_suggestions: (dict[str, str] | None) = None;

def _suggestion_for(tag: str) -> str {
    if _tag_suggestions is None {
        try {
            import from jaclang.client.targets.react_native.html_tag_map {
                rn_tag_suggestions
            }
            _tag_suggestions = rn_tag_suggestions();
        } except ImportError {
            _tag_suggestions = {};
        }
    }
    return _tag_suggestions.get(tag, _GENERIC_SUGGESTION);
}

walker JsxIntrinsicGuardPass(UniPass) {
    has _enforced_root: (str | None) = None,
        _exempt_paths: dict[str, bool] = {};

    def before_pass {
        self._enforced_root = self.ir_in.mobui_enforced_root;
        self._exempt_paths.clear();
    }

    can enter_module with Module entry {
        if self._enforced_root is None {
            osp_skip_rest();
        }
    }

    can enter_jsx_element with JsxElement entry {
        if isinstance(here.parent, JsxElement) {
            return;
        }
        self._check_element(here);
    }

    def _check_element(el: JsxElement) {
        if (
            self._enforced_root is not None
            and not self._is_exempt(el.loc.mod_path)
            and el.name is not None
            and el.name.parts
        ) {
            first = el.name.parts[0];
            tag = first.value or "" if isinstance(first, (Name, Token)) else "";
            if tag and tag[0].islower() and not self._resolves_in_scope(el, first) {
                self.emit(
                    E1105, node_override=first, tag=tag, suggestion=_suggestion_for(tag)
                );
            }
        }
        for child in (el.children or []) {
            if isinstance(child, JsxElement) {
                self._check_element(child);
            }
        }
    }

    def _resolves_in_scope(el: JsxElement, first: UniNode) -> bool {
        if not isinstance(first, Name) or not el.sym_tab or el.name is None {
            return False;
        }
        name_chain = [
            p
            for p in el.name.parts
            if isinstance(p, Name)
        ];
        el.sym_tab.chain_use_lookup(name_chain);
        return first.sym is not None;
    }

    def _is_exempt(mod_path: str) -> bool {
        if mod_path not in self._exempt_paths {
            self._exempt_paths[mod_path] = mobui_module_exempt(
                mod_path, self._enforced_root
            );
        }
        return self._exempt_paths[mod_path];
    }
}

import os;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.diagnostics { E1105 }

glob _COMPILER_INJECTED_JSX: set[str] = {"JacAwaiting", "JacClientErrorBoundary"},
     _RN_TAG_SUGGESTIONS: dict[str, str] = {
         "div": "View",
         "section": "View",
         "main": "View",
         "article": "View",
         "header": "View",
         "footer": "View",
         "nav": "View",
         "aside": "View",
         "ul": "ScrollView",
         "ol": "ScrollView",
         "li": "View",
         "form": "View",
         "span": "Text",
         "p": "Text",
         "h1": "Text",
         "h2": "Text",
         "h3": "Text",
         "h4": "Text",
         "h5": "Text",
         "h6": "Text",
         "label": "Text",
         "strong": "Text",
         "em": "Text",
         "small": "Text",
         "button": "Pressable",
         "a": "Pressable",
         "input": "TextInput",
         "textarea": "TextInput",
         "img": "Image"
     };

class JsxIntrinsicGuardPass(UniPass) {
    def enter_jsx_element(self: JsxIntrinsicGuardPass, nd: uni.JsxElement) -> None {
        if self.prog.project_kind != "mobui" {
            return;
        }
        mod_path = nd.loc.mod_path;

        project_root = self.prog.project_root;
        if project_root is not None {
            norm_path = os.path.normpath(mod_path);
            norm_root = os.path.normpath(project_root) + os.sep;
            if not norm_path.startswith(norm_root) {
                return;
            }
        }

        if mod_path.endswith('.cl.jac') {
            return;
        }

        if isinstance(nd.parent, uni.JsxElement) {
            return;
        }
        self._check_element(nd);
    }

    def _check_element(self: JsxIntrinsicGuardPass, el: uni.JsxElement) {
        if el.name is not None and el.name.parts {
            first = el.name.parts[0];
            tag = "";
            if isinstance(first, uni.Name) or isinstance(first, uni.Token) {
                tag = first.value or "";
            }

            resolved = False;
            if isinstance(first, uni.Name) and el.sym_tab {
                name_chain = [
                    p
                    for p in el.name.parts
                    if isinstance(p, uni.Name)
                ];
                el.sym_tab.chain_use_lookup(name_chain);
                resolved = first.sym is not None;
            }
            if not resolved {
                if tag in _COMPILER_INJECTED_JSX {
                    pass;
                } elif tag and tag[0].islower() {
                    suggestion = _RN_TAG_SUGGESTIONS.get(tag, "an @jac/ui component");
                    self.emit(
                        E1105, node_override=first, tag=tag, suggestion=suggestion
                    );
                }
            }
        }
        if el.children {
            for child in el.children {
                if isinstance(child, uni.JsxElement) {
                    self._check_element(child);
                }
            }
        }
    }
}

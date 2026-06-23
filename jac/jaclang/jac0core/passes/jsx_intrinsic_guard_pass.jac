"""JSX intrinsic guard pass — forbid raw HTML host tags in universal projects.

Universal projects (jac.toml ``[project] client_kind = "universal"``) target React
Native as well as the web, where intrinsic HTML host elements like ``<div>``
do not exist. This pass emits E1105 for every lowercase JSX tag in a universal
project, pointing at the @jac/ui / React Native component to use instead.

It runs in ``get_ir_gen_sched`` (always-on), so it fires on both ``jac check``
and ``jac build`` / dev — unlike the type checker, which is deliberately skipped
for ``.cl.jac`` modules (see #6262). Detection is scope-based: the tag name is
looked up in the enclosing symbol table via ``chain_use_lookup``. A name that
resolves to a user symbol is treated as an imported component and allowed
(regardless of case). Only unresolved lowercase names are treated as HTML host
elements and rejected. The allowlist ``_COMPILER_INJECTED_JSX`` carves out
synthesized runtime components that are never in user scope.

Element nodes are walked through the clean semantic ``children`` lists starting
from each root element. The parser additionally stores opening/closing tag-
marker twin ``JsxElement`` nodes inside every element's raw ``kid`` list (same
source span as the element itself); walking ``children`` from the roots visits
each real element exactly once and never touches those twins.
"""
import os;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.uni_pass { UniPass }
import from jaclang.jac0core.diagnostics { E1105 }

# Compiler-synthesized JSX component names that are never in user scope but
# must not be rejected by the guard. They are uppercase, so the islower
# fallback would also skip them — this set makes the carve-out explicit.
glob _COMPILER_INJECTED_JSX: set[str] = {"JacAwaiting", "JacClientErrorBoundary"},
     # Suggested replacement component for each known HTML host tag. Broadly
     # tracks the runtime RN dispatch in jac-client's html_tag_map.jac, but is
     # authoring guidance rather than a 1:1 mirror: list containers (ul/ol)
     # suggest ScrollView even though the runtime fallback still renders them as
     # a plain View. This map only drives the human-facing fix-it hint, not
     # enforcement (any lowercase tag is rejected whether or not it appears
     # here).
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

"""Forbid intrinsic HTML host tags in universal-project JSX (E1105)."""
class JsxIntrinsicGuardPass(UniPass) {
    def enter_jsx_element(self: JsxIntrinsicGuardPass, nd: uni.JsxElement) -> None {
        if self.prog.project_kind != "universal" {
            return;
        }
        mod_path = nd.loc.mod_path;
        # Project-root gate: only guard files inside the consumer's project
        # directory. Framework and library files (e.g. client_runtime.cl.jac)
        # are compiled into the same JacProgram during `jac build` but live
        # outside project_root — they must never be subject to E1105 regardless
        # of the consumer's kind. When project_root is None (no jac.toml found
        # or explicit override not supplied) the check is skipped and the guard
        # fires on everything, preserving pre-fix behaviour.
        project_root = self.prog.project_root;
        if project_root is not None {
            norm_path = os.path.normpath(mod_path);
            norm_root = os.path.normpath(project_root) + os.sep;
            if not norm_path.startswith(norm_root) {
                return;
            }
        }
        # Semantic gate: .cl.jac files are web-client boundary files and always
        # target the browser, even when they live inside the project root. Raw
        # HTML host elements are valid there regardless of project kind.
        if mod_path.endswith('.cl.jac') {
            return;
        }
        # Enter only at a semantic root (an element not nested directly inside
        # another element). Nested real elements and the tag-marker twins both
        # have a JsxElement parent and are reached — or skipped — via the
        # root's `children` walk in `_check_element`.
        if isinstance(nd.parent, uni.JsxElement) {
            return;
        }
        self._check_element(nd);
    }

    """Emit E1105 for `el`'s tag if it is an unresolved HTML host intrinsic,
    then recurse into its semantic JsxElement children."""
    def _check_element(self: JsxIntrinsicGuardPass, el: uni.JsxElement) {
        if el.name is not None and el.name.parts {
            first = el.name.parts[0];
            tag = "";
            if isinstance(first, uni.Name) or isinstance(first, uni.Token) {
                tag = first.value or "";
            }
            # Scope-based resolution: look up the full qualified chain so that
            # both bare names (<myWidget>) and dotted names (<ui.View>) resolve.
            # HTML intrinsics (div, span, ...) are never in the symbol table, so
            # their first.sym stays None after the lookup.
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
                    pass;  # compiler-synthesized, never in user scope — skip
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

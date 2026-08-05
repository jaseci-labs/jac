import from jaclang.compiler.passes.compose.view_ir { ComposeElement }
import from jaclang.compiler.passes.compose.compose_model { ComposeModule }
import from jaclang.compiler.passes.ecmascript.intent.model { IntentComponent }

obj ComposeNativeEmitter {
    has diagnostics: list[str] = [],
        indent: str = "    ",
        needs_coroutine_scope: bool = False;

    def emit_view(view: (ComposeElement | None)) -> str;
    def emit_component_view(model: ComposeModule, comp: IntentComponent) -> str;
    def _emit_element(elem: ComposeElement) -> any;
    def _emit_children(children: list) -> list;
    def _emit_child_list(children: list) -> list;
    def _scan_coroutine_need(elem: ComposeElement) -> None;
    def _event_needs_coroutine(attr: ComposeAttr) -> bool;
}

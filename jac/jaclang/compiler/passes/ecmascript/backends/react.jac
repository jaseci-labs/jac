"""React backend — lowers reactive-intent records to React hook ESTree."""

import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.framework_backend { FrameworkBackend }

obj ReactBackend(FrameworkBackend) {
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str;
    # Helpers reused across lower_* methods
    def _get_setter_name(var_name: str) -> str;
    def _jsx_fragment(children: list[es.Expression]) -> es.CallExpression;
}

"""Preact backend — hooks-based reactivity identical to React; differs in imports and entry."""

import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }

obj PreactBackend(ReactBackend) {
    def name -> str;
    def runtime_module -> str;
    def import_source(symbol: str) -> str;
    def runtime_source_basename -> str;
    def vite_aliases -> dict[str, str];
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str;
}

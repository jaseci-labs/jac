"""Walker / function graph-effect analysis for the client auto-cache.

The single authority for the `{is_writer, touches}` contract consumed by the
client SWR cache (`eb` / `__cachedEndpointCall`) and the server's endpoint
manifest. A *writer* endpoint invalidates the cached results of any *reader*
whose `touches` overlap; misclassifying a writer as a reader leaves the UI
showing stale data until a reload.

This pass runs after symbol resolution (and type checking), before
`EsastGenPass`. It classifies every walker archetype and every public
server-context module-level ability by the graph effects in its impl-resolved
body, following calls into helper abilities via *resolved symbols* -- so a
mutation hidden behind a `def` helper still marks its caller a writer. Results
are written into `mod.gen.client_manifest.endpoint_effects`, keyed
`walker:<name>` / `func:<name>`. The ES pass and the server are pure consumers
of that dict.

It replaces two hand-rolled classifiers that could diverge -- the lazy
spawn-site analysis formerly in `EsastGenPass._analyze_body_effects` and the
runtime `ModuleIntrospector._analyze_endpoint_effects` -- neither of which
covered walkers that are not spawned in a client context, and which used
syntactic name lookups rather than resolved symbols.

NOTE: keep this module's imports to `jac0core` only. Importing a
`jaclang.compiler.*` module (e.g. `symbol_utils`) at top level cycles through
`type_registry` while the codegen schedule is loading, which makes
`get_py_code_gen` silently fall back to a schedule without `EsastGenPass`.
"""
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { SymbolType, Tokens as Tok }
import from jaclang.jac0core.passes { UniPass }

"""Classify graph effects for every walker / public function declaration."""
class WalkerEffectsPass(UniPass) {
    def before_pass(self: WalkerEffectsPass) -> None;
    def enter_archetype(self: WalkerEffectsPass, nd: uni.Archetype) -> None;
    def enter_ability(self: WalkerEffectsPass, nd: uni.Ability) -> None;
    def _classify(self: WalkerEffectsPass, body_nodes: list) -> dict;
    def _scan(self: WalkerEffectsPass, nd: (uni.UniNode | None)) -> None;
    def _call_target_symbol(
        self: WalkerEffectsPass, call: uni.FuncCall
    ) -> (uni.Symbol | None);

    def _callee_body(self: WalkerEffectsPass, call: uni.FuncCall) -> list;
    def _resolved_body(self: WalkerEffectsPass, owner: uni.UniNode) -> list;
}

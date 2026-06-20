"""Capability / portability authority (One Owner Per Analysis, Phase 9).

ONE home for "can this construct ride this pathway" facts:

- `module_native_compat(mod)` derives `Module.gen.native_compat` (the
  auto-promotion eligibility fact) from a declarative disqualifier table
  instead of a hand-maintained visitor scan. `CapabilityCheckPass` stamps
  it at the tail of the front-end schedule.
- `PortabilityWarnPass` (check-extras schedule) owns the JS-idiom
  portability warnings (W6001-W6004): JS globals, JS-idiomatic methods,
  JS keywords used as identifiers, and JS property access. Warnings fire
  in ALL contexts (server, client, native) because Jac idioms are the
  preferred style everywhere - the ES backend translates Jac idioms to
  their JS equivalents.

Both shells consume the same declarative tables below; growing either
axis (a new disqualifier, a new JS-ism) is a table edit, not a new scan.
"""
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.diagnostics { E5090, W6001, W6002, W6003, W6004 }

# Python stdlib modules the native backend can lower: the allowlist of
# bare `import X;` modules whose member accesses the native codegen
# actually intercepts. A native import of anything NOT in this set is
# rejected (issue #6357) so it fails loudly instead of dropping the
# import and emitting a silently-wrong binary. This is the extension
# point for the Python-congruent native stdlib roadmap (issue #6404):
# list a module here in the SAME change that adds its codegen support.
# The rejection diagnostic fires from native import processing rather
# than CapabilityCheckPass because auto-promotion coerces a module to
# native context AFTER this pass runs; the legality TABLE lives here,
# the post-coercion enforcement point stays in the backend.
glob NATIVE_SUPPORTED_STDLIB: set[str] = {
         "sys",
         "math",
         "time",
         "os",
         "random",
         "struct"
     },
     # Statement / expression forms whose PRESENCE disqualifies a module from
     # native auto-promotion (no native lowering exists for them).
     NATIVE_DISQUALIFIER_NODES: tuple = (
         uni.VisitStmt,
         uni.DisengageStmt,
         uni.ReportStmt,
         uni.YieldExpr,
         uni.EdgeOpRef,
         uni.DisconnectOp,
         uni.TypedCtxBlock,
         uni.LambdaExpr,
         uni.PyInlineCode,
         uni.ClientBlock,
         uni.ServerBlock,

     );

# Match pattern forms the native backend cannot lower (structural
# patterns). Declarative E5090 territory: swept pre-codegen by
# native_capability_violations, alongside the disqualifier nodes above.
glob NATIVE_REJECT_MATCH_PATTERNS: tuple = (
         uni.MatchSequence,
         uni.MatchMapping,
         uni.MatchArch,
         uni.MatchStar,

     ),
     # Node kinds with NO native lowering, rejected pre-codegen in explicit
     # na {} / .na.jac code. DISTINCT from NATIVE_DISQUALIFIER_NODES (the
     # auto-promotion eligibility table, conservatively broader - lambdas
     # and the OSP statements are disqualifiers yet natively lowered).
     # Every entry here is verified unsupported against the native suite:
     #   - YieldExpr: generators have no native lowering.
     #   - DisconnectOp: edge disconnect has no native lowering (connect
     #     and traversal do - they ride the OSP kernel adjacency).
     #   - PyInlineCode: ::py:: blocks cannot execute in a native binary;
     #     before this table they were silently DROPPED in native context.
     NATIVE_REJECT_NODES: tuple = (uni.YieldExpr, uni.DisconnectOp, uni.PyInlineCode, );

"""Classify a plain `import X;` item for the native pathway: returns
(dotted_name, supported). `supported` is True exactly when the name is
in NATIVE_SUPPORTED_STDLIB; a (name, False) result in native context is
the E5090 rejection case (enforced by native_capability_violations)."""
def classify_native_import(item: uni.UniNode) -> tuple;

"""Declarative native-capability violations in `mod`'s native-context
code: (node, kind, name, help_text | None) tuples ready to emit as
E5090. Covers structural match patterns, the NATIVE_REJECT_NODES kinds,
and non-allowlisted Python imports - NOT the auto-promotion disqualifier
table, which is conservatively broader than what explicit native code
can lower (see the table comments). Invoked by the native backend at the
START of emission - after auto-promotion has coerced contexts, which is
why this cannot run inside CapabilityCheckPass itself - so codegen-time
E5090s remain only for value- and shape-conditional gaps the emitter
discovers."""
def native_capability_violations(mod: uni.Module) -> list;

"""Whether a module is eligible for native auto-promotion: it must have a
`with entry` block and contain none of the disqualifying constructs (no
OSP archetypes, no async or event abilities, none of the node forms in
NATIVE_DISQUALIFIER_NODES)."""
def module_native_compat(mod: uni.Module) -> bool;

"""Stamps `Module.gen.native_compat` from the declarative capability
table. Scheduled once at the tail of the front-end schedule (the slot the
deleted UniTreeEnrichPass occupied)."""
obj CapabilityCheckPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
}

"""Portability warnings (W6001-W6004) over the analyzed tree. Scheduled
in the check-extras schedule (`jac check`); diagnostic-only."""
obj PortabilityWarnPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    def _check_js_globals(mod: uni.Module) -> None;
    def _check_js_methods(mod: uni.Module) -> None;
    def _check_js_keywords(mod: uni.Module) -> None;
    def _check_js_properties(mod: uni.Module) -> None;
}

"""Surfaces native-capability violations (E5090) over explicitly-native code
at `jac check` time. The native backend runs the same
`native_capability_violations` sweep at the START of emission; this pass runs
it during `jac check` (which compiles with codegen OFF, so the backend never
runs), so structural native gaps -- non-allowlisted Python imports, structural
match patterns, `skip` in a value-returning function -- are reported by `check`
and not only by `jac nacompile` (issue #6636). Scheduled in the check-extras
schedule, which runs ONLY for `jac check`; native emission runs in a disjoint
invocation (type_check off), so a violation is surfaced exactly once."""
obj NativeCapabilityCheckPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
}

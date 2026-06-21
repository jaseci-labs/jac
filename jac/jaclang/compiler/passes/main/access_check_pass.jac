"""Access-modifier enforcement pass for the Jac compiler.

Enforces the meaning of the `:pub` / `:protect` / `:priv` access tags along two
axes, depending on where the accessed symbol is declared:

* Member encapsulation -- a `has` field, `def`/`can` ability, or nested
  archetype/enum declared inside an archetype:
    - pub     accessible anywhere
    - protect accessible inside the declaring class and its subclasses
    - priv    accessible only inside the declaring class

* Module / project visibility -- a top-level `glob` / `obj` / `def` / `enum` /
  `walker`. A project is the directory tree rooted at its `jac.toml`:
    - pub     visible from any module, including a consuming project (an
              exported library endpoint -- it need not be used in its own project)
    - protect visible from any module within the same project
    - priv    visible only inside the declaring module

Violations are reported as warnings by default and promoted to hard errors when
`[check] enforce_access = true` is set in the project's jac.toml.

The pass runs in the type-check schedule, after type inference has resolved
member and qualified-name symbols, so it reads already-stamped `.sym` links and
does not perform name resolution of its own.
"""
import os;
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.passes.transform { Transform }
import from jaclang.jac0core.constant { SymbolAccess }
import from jaclang.jac0core.modresolver { find_jac_project_root }
import from jaclang.jac0core.diagnostics {
    DiagnosticInfo,
    E2034,
    W2034,
    E2035,
    W2035,
    E2037,
    W2037,
    E2038,
    W2038
}

"""Enforce access modifiers across class, module, and project boundaries.

Like StaticAnalysisPass, all work happens in transform() via bulk sub-node
queries rather than node-by-node traversal, so we extend Transform directly.
"""
obj AccessCheckPass(Transform[uni.Module, uni.Module]) {
    has ir_in: uni.Module,
        prog: any,
        cancel_token: any = None,
        _enforce: bool = False;

    def postinit -> None;
    def transform(ir_in: uni.Module) -> uni.Module;
    """Read [check] enforce_access from the active project config."""
    def _read_enforce -> bool;

    """Dispatch one resolved name use to the member or visibility check."""
    def _check_use(use_node: uni.AstSymbolNode, sym: uni.Symbol) -> None;

    """Apply OOP member-encapsulation rules to a member access."""
    def _check_member(
        use_node: uni.AstSymbolNode, sym: uni.Symbol, owner: uni.Archetype
    ) -> None;

    """Emit warn (default) or err (enforce_access) for an access violation."""
    def _emit_pair(
        warn: DiagnosticInfo, err: DiagnosticInfo, at_node: uni.UniNode, **kwargs: any
    ) -> None;

    """Return the archetype that declares `sym` as a member, else None."""
    def _declaring_archetype(sym: uni.Symbol) -> (uni.Archetype | None);

    """Resolve a base-class expression to the archetype it names, else None."""
    def _base_archetype(expr: uni.UniNode) -> (uni.Archetype | None);

    """True if `child` is `ancestor` or transitively derives from it."""
    def _is_subclass_of(child: uni.Archetype, ancestor: uni.Archetype) -> bool;
}

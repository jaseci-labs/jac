"""Regression: type_utils.lookup_symtab must never form a parent_scope cycle.

Two distinct `builtins` stub modules can coexist during a build -- e.g.
BoundaryAnalysisPass parses a native (`.na.jac`) module into a throwaway
JacProgram that loads its own builtins stub. The shared type evaluator then
injects each as the other's builtins fallback, which once set
`A.parent_scope = B` *and* `B.parent_scope = A`: a parent_scope cycle.

Every scope walk that follows `parent_scope` (Symbol.sym_dotted_name,
Symbol.storage, UniScopeNode.lookup, ...) is written as an unguarded loop, so a
cyclic chain spins forever -- sym_dotted_name appends to a list every iteration,
exhausting memory and OOM-killing the native single-binary JIR precompile with
zero JIR produced (the `mkpayload` build step then fails). See issue #6964.

The fix is to never create the cycle in the first place: lookup_symtab only
links `mod` under `builtins_to_inject` when that does not close a loop.
"""

import from jaclang.jac0core.compiler { JacCompiler }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.passes.sym_tab_build_pass { SymTabBuildPass }
import from jaclang.compiler.type_system.type_utils { lookup_symtab }

"""True if walking `scope.parent_scope` ever revisits a node (the chain loops)."""
def _scope_chain_loops(scope: any) -> bool {
    seen = set();
    cur = scope;
    while cur is not None {
        if id(cur) in seen {
            return True;
        }
        seen.add(id(cur));
        cur = cur.parent_scope;
    }
    return False;
}

"""Parse `src`, build its symbol table, and return the root-scoped Module."""
def _module_with_symtab(src: str, path: str) -> any {
    prog = JacProgram();
    mod = JacCompiler().parse_str(source_str=src, file_path=path, target_program=prog);
    SymTabBuildPass(ir_in=mod, prog=prog);
    return mod;
}

test "lookup_symtab never forms a parent_scope cycle between modules" {
    mod_a = _module_with_symtab("glob g_a = 1;\n", "cycle_a.jac");
    mod_b = _module_with_symtab("glob g_b = 1;\n", "cycle_b.jac");
    assert mod_a.parent_scope is None , mod_a.parent_scope;
    assert mod_b.parent_scope is None , mod_b.parent_scope;

    # Mirror the duplicate-builtins situation: inject each module as the other's
    # builtins fallback. Each call resolves that module's OWN global, so it
    # returns on the local-scope hit instead of walking (and, pre-fix, looping
    # forever on) the parent chain it just linked.
    lookup_symtab(mod_a, "g_a", mod_b);
    lookup_symtab(mod_b, "g_b", mod_a);

    assert not _scope_chain_loops(mod_a) , "mod_a parent_scope chain is cyclic";
    assert not _scope_chain_loops(mod_b) , "mod_b parent_scope chain is cyclic";
}

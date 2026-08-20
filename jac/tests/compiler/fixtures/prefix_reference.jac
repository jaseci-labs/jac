"""A reference prefix entry: the crossing's contract, written in Python.

The native `parse_and_run_prefix` does not exist yet. This module implements
the same contract on the bytecode tier -- parse, take the driver-stamped
facts, run the claimed prefix passes, hand back the executed list -- so the
flip machinery has something real to route through before the crossing lands.

Two uses:

  * `reference_prefix_entry` is the honest stand-in. Routing a compile through
    it must produce the same module the staged route produces, because it runs
    the same passes in the same order. The parity harness asserts exactly
    that, which makes it a live test of the ROUTING (schedule trimming,
    PROVIDES marking, facts stamping) rather than of the passes.

  * `diverging_prefix_entry` is the injected-divergence fixture. It parses,
    perturbs one string literal, and executes nothing -- so the driver runs
    the whole staged schedule over a tree that differs from the staged tree by
    one token. A parity harness that cannot see that difference is not a
    harness, and the red-first test asserts it does.

The entry contract, verbatim:

    entry(source_str, file_path, prog, claimed, facts)
        -> (module, had_error, executed, clause, detail)

`executed` is a prefix of `claimed`, possibly empty; short means declined and
`clause`/`detail` name why.
"""

import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.compiler {
    get_ir_gen_sched,
    get_symtab_ir_sched,
    run_pass
}
import from jaclang.jac0core.parser { parse as rd_parse }

glob PERTURBED_LITERAL: str = "__prefix_divergence_marker__";

"""Map the claimed pass names onto the real classes, drawing from every
schedule shape the prefix claims. An unknown name is a pin drift, not a
fallback."""
def resolve_prefix_passes(claimed: tuple[str]) -> list[any] {
    pool: dict[str, any] = {};
    for sched in [
        get_ir_gen_sched(gen_mtir=True),
        get_ir_gen_sched(gen_mtir=False),
        get_symtab_ir_sched()
    ] {
        for p in sched {
            pool[p.__name__] = p;
        }
    }
    out: list[any] = [];
    for name in claimed {
        cls = pool.get(name);
        if cls is None {
            raise LookupError(f"the prefix claims {name}, which no schedule contains");
        }
        out.append(cls);
    }
    return out;
}

"""Stamp the Module facts the driver owns onto the materialized tree. The
native crossing does this natively; here it is one assignment each, and it
documents exactly which fields must cross as data."""
def apply_prefix_facts(mod: any, facts: any) {
    mod.jac_project_root = facts.jac_project_root;
    mod.access_enforced = facts.access_enforced;
}

def reference_prefix_entry(
    source_str: str, file_path: str, prog: any, claimed: tuple[str], facts: any
) -> tuple[any] {
    (mod, had_error) = rd_parse(source_str, file_path, prog=prog);
    if had_error {
        return (mod, had_error, (), "prefix-declined", "the source did not parse");
    }
    apply_prefix_facts(mod, facts);
    comp = prog._get_compiler();
    for imp in mod.get_all_sub_nodes(uni.Import) {
        if imp.is_absorb {
            return (
                mod,
                had_error,
                (),
                "absorbed-mod-present",
                f"{file_path} absorbs another module",

            );
        }
    }
    executed: list[str] = [];
    for (name, cls) in zip(claimed, resolve_prefix_passes(claimed)) {
        if name == "SymTabBuildPass" {
            comp.resolve_absorb_imports(mod, prog);
        }
        if name == "JsxIntrinsicGuardPass" {
            comp.stamp_client_kind_facts(mod, prog);
        }
        run_pass(cls, mod, prog);
        executed.append(name);
    }
    return (mod, had_error, tuple(executed), "", "");
}

"""A prefix that parses to a DIFFERENT tree and executes nothing.

Executing nothing keeps the compile well-formed -- the driver runs the whole
staged schedule -- so the only difference between the two routes is the one
perturbed literal. That isolates the harness's detector: a green run here
means the harness is blind."""
def diverging_prefix_entry(
    source_str: str, file_path: str, prog: any, claimed: tuple[str], facts: any
) -> tuple[any] {
    (mod, had_error) = rd_parse(source_str, file_path, prog=prog);
    apply_prefix_facts(mod, facts);
    for nd in mod.get_all_sub_nodes(uni.String) {
        nd.value = f'"{PERTURBED_LITERAL}"';
        nd.gen.jac = "";
        break;
    }
    return (mod, had_error, (), "prefix-declined", "divergence fixture");
}

"""A prefix that reports passes the schedule does not lead with. The driver
must refuse this loudly: it means the crossing ran something the driver never
scheduled."""
def lying_prefix_entry(
    source_str: str, file_path: str, prog: any, claimed: tuple[str], facts: any
) -> tuple[any] {
    (mod, had_error) = rd_parse(source_str, file_path, prog=prog);
    return (mod, had_error, ("NoSuchPass", ), "", "");
}

"""A prefix that raises. The driver must count it as crossing-error and still
return a usable module from the staged route."""
def exploding_prefix_entry(
    source_str: str, file_path: str, prog: any, claimed: tuple[str], facts: any
) -> tuple[any] {
    raise RuntimeError("the crossing exploded");
}

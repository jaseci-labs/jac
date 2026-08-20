"""Zero reachable demotions across every sealed root (epic #8201 phase C4).

The per-root coverage files each pin one root. This is the branch-wide
audit: it walks every entry in `NATIVE_SEAL_ROOTS`, measures it the way
`seal_native_artifacts` measures it, and holds the whole seal to one
statement.

**The demotion report equals the enumerated waiver list. Exactly.**

Not "at most", not "fewer than last time". A seam that no waiver names
fails, and a waiver that names no seam fails, for every root at once.
That is the same two-way check each wave coverage performs, applied across
the branch so a root cannot be added without its waivers or kept after
its seams clear.

Two further obligations, which are what make a waiver a debt rather than
an exemption:

  - **Every waiver names its clearing mechanism.** Each one has to fall
    in a family in `NATIVE_SEAL_WAIVER_FAMILIES`, and each family has to
    cover something. A waiver with no recorded way out is indefinite by
    construction, and this fails on it.
  - **Every waived name is owed by a module the root links.** A waiver
    is a debt, and a debt has an owner. A name whose module is neither
    the root nor a member of `NATIVE_SEAL_CLOSURE` is bookkeeping for
    work that is not happening in this artifact, and it hides whoever
    the real owner is.

    This slot once held a stronger rule -- that no waived name may be a
    module-level function of a dependency at all, because nothing emits
    a stub for one and `dlopen` then fails on an advertised, absent
    symbol. That was written for `codegen_ir`'s `decode_ops`, which cost
    a three-minute link to find. It does not hold of the closure every
    root links today: the type system arrives as a layout dependency of
    `unitree` with twenty-one such functions across `type_utils`,
    `types` and `helpers`, and every artifact links and loads. The seal
    itself is the check that survived -- it `dlopen`s each artifact it
    builds and probes its symbols before recording it, which is stronger
    than any static approximation.

Reachability is the other half and lives in
`test_sealed_seam_reachability.jac`: it proves no waived name can be
called from a root's live entry surface, so every stub this audit
tolerates ships dead.

Running the audit prints the report to stderr, grouped by root and
family, so a reviewer can read the whole debt in one place. Under
`jac test` a passing test's output is hidden, and since the runner came
in-house (#8287) there is no capture-off switch to turn it back on, so
the report is readable from a failing run.

The measurement is a source-lane one: under a sealed jaclang image the
coverage reads the image's trust boundary instead of each unit's own
coupling, so the audit skips there.
"""

import os;
import sys;
import jaclang;
import from pathlib { Path }
import from jaclang.jac0core.compile_options { CompileOptions }
import from jaclang.jac0core.compiler { na_coverage_begin, na_coverage_end }
import from jaclang.jac0core.program { JacProgram }
import from jaclang.jac0core.sealed { _jaclang_image, native_artifact_for }
import from jaclang.utils.precompile_bytecode {
    NATIVE_SEAL_CLOSURE,
    NATIVE_SEAL_DEMOTION_WAIVERS,
    NATIVE_SEAL_REFUSED_ROOTS,
    NATIVE_SEAL_ROOTS,
    NATIVE_SEAL_WAIVER_FAMILIES,
    seal_waiver_names
}

glob PKG_PATH = Path(jaclang.__file__).parent;

"""Sealed roots plus the ones measured and refused.

A refused root still carries a coverage report and a waiver set that have to
hold; refusing it withholds the artifact, not the accounting.
"""
glob AUDITED_ROOTS: tuple = tuple(
         list(NATIVE_SEAL_ROOTS) + sorted(NATIVE_SEAL_REFUSED_ROOTS)
     );

glob _COVERAGE_MEMO: dict[(str, tuple)] = {};

"""A root's dotted module name, for the sealed-runtime skip gate."""
def _root_module_name(rel: str) -> str {
    return "jaclang." + rel[:-4].replace("/", ".");
}

"""Skip when this runtime is itself sealed; the coverage would measure it."""
def _require_source_lane {
    if _jaclang_image() is not None {
        testskip(
            "this runtime is a sealed jaclang image; a source coverage here "
            "measures the image's trust boundary, not each unit's own seams"
        );
    }
}

"""Compile one root the way seal_native_artifacts does, up to the coverage."""
def _root_coverage(rel: str) -> tuple {
    if rel in _COVERAGE_MEMO {
        return _COVERAGE_MEMO[rel];
    }
    prog = JacProgram();
    na_coverage_begin();
    try {
        ir = prog.compile(
            file_path=str(PKG_PATH / rel),
            options=CompileOptions(
                aot_mode=True,
                type_check=False,
                force_codespace='native',
                force_target_program=True,
                na_gc_mode='cycles',
                no_ir_cache=True
            )
        );
    } finally {
        coverage = na_coverage_end();
    }
    has_ir = ir is not None and ir.gen.llvm_ir is not None;
    errors = [str(e) for e in prog.errors_had];
    result = (coverage, has_ir, errors, );
    _COVERAGE_MEMO[rel] = result;
    return result;
}

"""Coverage seams as `<pkg-rel module>::<Type>.<method>` -> reason."""
def _seams_by_key(rel: str) -> dict[(str, str)] {
    (coverage, _has_ir, _errors) = _root_coverage(rel);
    found: dict[(str, str)] = {};
    for (path, rec) in sorted(coverage.items()) {
        where = Path(path).resolve().relative_to(PKG_PATH.resolve()).as_posix();
        for seam in (rec["seams"] or []) {
            (name, sep, why) = str(seam).partition(": ");
            found[f"{where}::{name if sep else str(seam)}"] = why if sep else "";
        }
        if rec["outcome"] == "demoted" {
            found[f"{where}::<module>"] = f"[{rec['code']}] {rec['detail']}";
        }
    }
    return found;
}

"""Roots the audit can measure here, plus the two kinds it cannot.

A root served from this runtime's own seal was already gated by the
build. A generated root has no source to compile: `native_materialize`
is written by `gen_native_materialize` from the unitree layout during
the seal itself, so it exists only inside a seal run and is measured
there.
"""
def _auditable_roots -> tuple {
    live: list[str] = [];
    served: list[str] = [];
    generated: list[str] = [];
    for rel in AUDITED_ROOTS {
        if native_artifact_for(_root_module_name(rel)) is not None {
            served.append(rel);
        } elif not (PKG_PATH / rel).is_file() {
            generated.append(rel);
        } else {
            live.append(rel);
        }
    }
    return (live, served, generated, );
}

"""Waiver name -> the family that records how it clears."""
def _family_of_waiver -> dict[(str, str)] {
    owner: dict[(str, str)] = {};
    for (label, members, _mechanism) in NATIVE_SEAL_WAIVER_FAMILIES {
        for name in members {
            owner[name] = label;
        }
    }
    return owner;
}

"""Every waiver name registered against an audited root."""
def _all_waived_names -> set[str] {
    names: set[str] = set();
    for rel in AUDITED_ROOTS {
        (allowed, _bare) = seal_waiver_names(rel);
        for name in allowed {
            names.add(name);
        }
    }
    return names;
}


test "every sealed root's demotion report is exactly its waiver list" {
    _require_source_lane();
    (live, served, generated) = _auditable_roots();
    assert live , (
        "every sealed root is served from this runtime's own seal, so the "
        "audit measured nothing; run it on a source-lane runtime"
    );
    failures: list[str] = [];
    for rel in live {
        (_coverage, has_ir, errors) = _root_coverage(rel);
        if errors {
            failures.append(
                f"{rel}: {len(errors)} compile error(s), so its coverage means "
                f"'not reached' rather than 'clean': {errors[:3]}"
            );
            continue;
        }
        if not has_ir {
            failures.append(
                f"{rel}: no LLVM IR, so a zero-seam coverage would be vacuous"
            );
            continue;
        }
        seams = _seams_by_key(rel);
        (allowed, _bare) = seal_waiver_names(rel);
        unwaived = sorted(
            k
            for k in seams
            if k not in allowed
        );
        stale = sorted(
            k
            for k in allowed
            if k not in seams
        );
        for k in unwaived {
            failures.append(f"{rel}: un-waived seam {k}: {seams[k]}");
        }
        for k in stale {
            failures.append(f"{rel}: waiver {k} no longer names a seam");
        }
    }
    assert not failures , (
        f"{len(failures)} demotion(s) diverge from the enumerated waiver "
        "list across the sealed roots. An un-waived seam ships an abort "
        "stub; a stale waiver hides a fix that already landed.\n"
        + "\n".join(f"  {f}" for f in failures)
    );
    if served {
        sys.stderr.write(
            f"\n  audit: {len(served)} root(s) served from this runtime's "
            f"seal and measured by the build instead: {', '.join(served)}\n"
        );
    }
    if generated {
        sys.stderr.write(
            f"  audit: {len(generated)} generated root(s) with no source to "
            f"compile, measured inside the seal: {', '.join(generated)}\n"
        );
    }
}


test "every waiver names the mechanism that clears it" {
    owner = _family_of_waiver();
    orphans = sorted(
        name
        for name in _all_waived_names()
        if name not in owner
    );
    assert not orphans , (
        f"{len(orphans)} waiver(s) belong to no family in "
        "NATIVE_SEAL_WAIVER_FAMILIES, so nothing records how they clear. A "
        "waiver with no way out is a permanent exemption; give it a family "
        "or drop it:\n"
        + "\n".join(f"  {n}" for n in orphans)
    );
}


test "every waiver family covers a registered waiver" {
    registered = _all_waived_names();
    empty: list[str] = [];
    for (label, members, mechanism) in NATIVE_SEAL_WAIVER_FAMILIES {
        assert mechanism.strip() , f"family {label!r} records no mechanism";
        covered = [
            name
            for name in members
            if name in registered
        ];
        if not covered {
            empty.append(label);
        }
    }
    assert not empty , (
        f"{len(empty)} waiver family(ies) cover nothing registered against a "
        f"sealed root, so the table has drifted from the tuples: {empty}"
    );
}


test "every waived foreign name belongs to a module the root links" {
    # This slot used to hold a stronger rule: that no waived name may be a
    # module-level function of a dependency at all, on the theory that such
    # a name is advertised by the layout and absent from the artifact, so
    # `dlopen` fails. That was true when `codegen_ir`'s `decode_ops` was
    # the only instance and it cost a three-minute link to find. It is not
    # true of the closure every sealed root links today: the type system
    # arrives as a layout dependency of `unitree`, bringing eleven demoted
    # `type_utils` free functions, one in `types` and nine in `helpers`,
    # and every root still links and loads -- the seal runs a real `dlopen`
    # plus symbol probe on each artifact it builds and refuses one that
    # fails, which is a stronger check than this static one ever was.
    #
    # What is left is accounting the static view can still make. A waiver
    # names a debt, and a debt has to be owed by a module this root
    # actually links. A waiver for a module outside the sealed closure is
    # bookkeeping for work that is not happening here, and it hides the
    # real owner.
    orphans: list[str] = [];
    for rel in AUDITED_ROOTS {
        (allowed, _bare) = seal_waiver_names(rel);
        for name in sorted(allowed) {
            (owner, _sep, member) = name.partition("::");
            if (
                "." not in member and owner != rel and owner not in NATIVE_SEAL_CLOSURE
            ) {
                orphans.append(f"{rel}: {name}");
            }
        }
    }
    assert not orphans , (
        "a waiver names a module-level function of a module that is not in "
        "`NATIVE_SEAL_CLOSURE`, so the root does not link it and the waiver "
        "accounts for work that is not happening here:\n"
        + "\n".join(f"  {o}" for o in orphans)
    );
}


test "the audit reports the whole waived surface" {
    _require_source_lane();
    (live, _served, generated) = _auditable_roots();
    owner = _family_of_waiver();
    mechanisms: dict[(str, str)] = {};
    for (label, _members, mechanism) in NATIVE_SEAL_WAIVER_FAMILIES {
        mechanisms[label] = mechanism;
    }
    nl = chr(10);
    lines: list[str] = [
        "",
        "  === sealed-root demotion audit ===",
        f"  roots measured: {len(live)} of {len(AUDITED_ROOTS)}"
    ];
    if generated {
        lines.append(f"  generated, measured inside the seal: {', '.join(generated)}");
    }
    total = 0;
    for rel in live {
        seams = _seams_by_key(rel);
        (allowed, _bare) = seal_waiver_names(rel);
        waived = sorted(
            k
            for k in seams
            if k in allowed
        );
        total += len(waived);
        lines.append(f"  {rel}: {len(waived)} waived");
        by_family: dict[(str, list)] = {};
        for name in waived {
            label = owner[name] if name in owner else "<unfamilied>";
            if label not in by_family {
                by_family[label] = [];
            }
            by_family[label].append(name);
        }
        for label in sorted(by_family) {
            lines.append(f"    [{label}] {len(by_family[label])}");
            for name in by_family[label] {
                lines.append(f"      {name.split('::')[-1]}");
            }
        }
    }
    lines.append(f"  total waived demotions across measured roots: {total}");
    lines.append("  clearing mechanisms:");
    for label in sorted(mechanisms) {
        lines.append(f"    [{label}] {mechanisms[label]}");
    }
    lines.append("");
    sys.stderr.write(nl.join(lines) + nl);
    sys.stderr.flush();
    assert total >= 0;
}

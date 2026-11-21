"""Structural guard on the diagnostic-code registry.

Three code collisions landed inside forty-eight hours (E0108 twice, E0109
once), each one a semantic merge artifact: two pull requests independently
claimed the same code, both were green alone, and the merge of the two
produced a `diagnostics.jac` with two `glob` entries of one name. Nothing
in the bytecode lane objects to that. The second binding shadows the first,
the first diagnostic's pins keep matching a message that is no longer
registered, and the failure only surfaced in the native lane, where the
link refuses the module outright on a symbol self-collision.

The registry is therefore guarded on both halves of that shape:

- `_reg` refuses a second claimant for a live code at registry-build time,
  which is import time, so the collision fails on the next jac invocation
  of any kind rather than several merges later at a native link.
- Every registered code keeps a module-level binding of its own name that
  is exactly the object the registry holds. A second `glob` of an existing
  name spelled with a fresh code passes the first guard and is caught here:
  the binding and the registry entry come apart.

Both failures name both claimants, because the merge that produced the
collision is the thing that has to be undone and neither half of it is
recoverable from the code alone.
"""

import jaclang.compiler.frontend.diagnostics as diagmod;
import from jaclang.compiler.frontend.diagnostics { Category, DIAGNOSTICS, Severity }

test "the registry holds one entry per code, bound under its own name" {
    assert DIAGNOSTICS , "the diagnostic registry is empty";
    for (code, info) in DIAGNOSTICS.items() {
        assert info.code == code , f"registry key {code} holds a diagnostic whose own code is {info.code}";
        bound = getattr(diagmod, code, None);
        assert bound is not None , f"diagnostic {code} is registered but has no module-level binding of that name";
        assert bound is info , (
            f"module binding {code} holds the diagnostic registered as "
            f"{bound.code} ({bound.message_template!r}), not the one the "
            f"registry has under {code} ({info.message_template!r}). Two "
            f"declarations claim the name {code}; the later one shadows "
            f"the earlier."
        );
    }
}

test "a second claimant for a live code fails the registry build, naming both" {
    prior = DIAGNOSTICS["E0001"];
    with testraises(ValueError) as excinfo {
        diagmod._reg(
            "E0001",
            Severity.ERROR,
            Category.SEMANTIC,
            "second claimant planted by the registry guard test"
        );
    }
    msg = str(excinfo.value);
    assert "E0001" in msg;
    assert prior.message_template in msg , f"the sitting claimant is not named in: {msg}";
    assert "second claimant planted by the registry guard test" in msg , f"the arriving claimant is not named in: {msg}";
    assert DIAGNOSTICS["E0001"] is prior , "the refused registration overwrote the sitting entry anyway";
}

test "the guard admits a code the registry has never seen" {
    code = "E0001-registry-guard-probe";
    assert code not in DIAGNOSTICS;
    info = diagmod._reg(
        code, Severity.ERROR, Category.SEMANTIC, "probe", blocks_codegen=False
    );
    assert DIAGNOSTICS[code] is info;
    del DIAGNOSTICS[code];
}


test "no diagnostic code is claimed twice in the registry source" {
    # The import-time guard fires only once the compiler is loaded, which on a
    # merged branch is the sealed kit failing to build. This reads the source
    # the way a merge produced it, so the collision is named before anything
    # imports it (#8982 item 7); the same scan runs in CI's contribution checks.
    import os;
    import re;
    src_path = os.path.join(os.path.dirname(str(diagmod.__file__)), "diagnostics.jac");
    with open(src_path) as fh {
        src = fh.read();
    }
    claims = re.findall(r'\b([EW]\d{4}) = _(?:err|warn)\(\s*"([EW]\d{4})"', src);
    assert len(claims) == len(DIAGNOSTICS) , (
        f"the source scan found {len(claims)} registrations but the registry "
        f"holds {len(DIAGNOSTICS)}; the scan's pattern no longer matches how "
        "codes are declared"
    );
    seen: dict[str, int] = {};
    for (bound, literal) in claims {
        assert bound == literal , f"binding {bound} registers code {literal}";
        seen[literal] = seen.get(literal, 0) + 1;
    }
    dupes = sorted(
        code
        for (code, n) in seen.items()
        if n > 1
    );
    assert not dupes , (
        f"diagnostic code(s) claimed more than once: {', '.join(dupes)}; two "
        "branches each took the next free number and the merge kept both"
    );
}

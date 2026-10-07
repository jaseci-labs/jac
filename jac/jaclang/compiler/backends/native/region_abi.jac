import os;

glob REGION_KERNEL_ABI: dict[str, tuple[bool, int]] = {
         "__jac_region_new": (True, 0),
         "__jac_region_alloc": (True, 2),
         "__jac_region_log_dtor": (False, 3),
         "__jac_region_drop": (False, 1),
         "__jac_region_partition": (True, 1),
         "__jac_region_enter": (False, 1),
         "__jac_region_leave": (False, 0),
         "__jac_region_unwind": (False, 1),
         "__jac_region_current": (True, 0),
         "__jac_region_depth": (True, 0),
         "__jac_region_of": (True, 1),
         "__jac_region_owns": (True, 1)
     };

def _region_layout_facts -> dict[str, int] {
    import from jaclang.compiler.frontend.codeinfo {
        HDR_ALLOC_ID_OFF,
        HDR_DTOR_OFF,
        HDR_MAGIC,
        HDR_MAGIC_SHIFT_BASE,
        HDR_RC_OFF,
        HDR_TAG_OFF,
        HDR_TOTAL,
        RC_SENTINEL
    }
    return {
        "HDR_ALLOC_ID_OFF": HDR_ALLOC_ID_OFF,
        "HDR_TAG_OFF": HDR_TAG_OFF,
        "HDR_RC_OFF": HDR_RC_OFF,
        "HDR_DTOR_OFF": HDR_DTOR_OFF,
        "HDR_TOTAL": HDR_TOTAL,
        "HDR_MAGIC": HDR_MAGIC,
        "HDR_MAGIC_SHIFT_BASE": HDR_MAGIC_SHIFT_BASE,
        "ARENA_MAGIC_SHIFT_BASE": (HDR_MAGIC + 1) * 4294967296,
        "RC_SENTINEL": RC_SENTINEL
    };
}

"""The integer literal the first `<name>: int = <literal>` declaration in the
source gives, as its text; None when the source has no such declaration."""
def _declared_int(source: str, name: str) -> (str | None) {
    lead = f"{name}: int = ";
    at = source.find(lead);
    while at >= 0 {
        before = source[at - 1] if at > 0 else " ";
        if not (before.isalnum() or before == "_") {
            start = at + len(lead);
            stop = start;
            if source[stop:stop + 1] == "-" {
                stop += 1;
            }
            digits = stop;
            while stop < len(source) and source[stop] in "0123456789" {
                stop += 1;
            }
            if stop > digits {
                return source[start:stop];
            }
        }
        at = source.find(lead, at + 1);
    }
    return None;
}

def verify_region_layout(source: str) {
    facts = _region_layout_facts();
    for (name, want) in facts.items() {
        declared = _declared_int(source, name);
        if declared is None {
            raise RuntimeError(
                f"region kernel unit does not declare {name}; the header layout "
                f"is defined once in compiler/frontend/codeinfo.jac and restated "
                f"in runtime/region_native.jac"
            );
        }
        if int(declared) != want {
            raise RuntimeError(
                f"region kernel unit declares {name} = {declared} but "
                f"compiler/frontend/codeinfo.jac says {want}; update "
                f"runtime/region_native.jac to match"
            );
        }
    }
}

def verify_region_unit(path: str) {
    with open(path, "r", encoding="utf-8") as f {
        verify_region_layout(f.read());
    }
}

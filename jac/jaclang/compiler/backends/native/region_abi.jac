"""The C ABI of the region arena unit (`runtime/region_native.jac`).

Every entry is a `:pub` function of that unit, so the symbols are bare and
the emitter may declare them by name; the unit is pulled into a link by the
dependency edge `NaIRGenRegion._register_region_kernel` records. The header
layout the arena restates is checked against `codeinfo.jac` here, so the
two never drift apart silently.
"""
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

"""Refuse a region unit whose restated header constants disagree with the
compiler's. Called by the link plan before the arena joins an artifact."""
def verify_region_layout(source: str) {
    import re;
    facts = _region_layout_facts();
    for (name, want) in facts.items() {
        m = re.search(rf"\b{name}: int = (-?\d+)", source);
        if m is None {
            raise RuntimeError(
                f"region kernel unit does not declare {name}; the header layout "
                f"is defined once in compiler/frontend/codeinfo.jac and restated "
                f"in runtime/region_native.jac"
            );
        }
        if int(m.group(1)) != want {
            raise RuntimeError(
                f"region kernel unit declares {name} = {m.group(1)} but "
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

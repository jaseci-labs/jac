"""Cross-backend OSP equivalence fixture: subtype + union/tuple trigger dispatch.

`with Base entry` must fire on a `Sub` instance (subtype-aware dispatch), and a
tuple trigger `with (Sub, Other) entry` fires on either member. Spawning the
same walker on `Sub(5)` then `Other(7)`:
  - `on_base` (trigger `Base`) fires only on `Sub`        -> base = 5
  - `on_either` (trigger `(Sub, Other)`) fires on both    -> either = 12

Backend status: na dispatch keys on the exact type tag (no `is_a`), so it
silently MISSES the subtype/tuple firing and returns base=0 -- a real native
gap. py-only until native dispatch gains subtype matching; cl is unwired.
"""

node Base { has val: int; }
node Sub(Base) {}
node Other { has val: int; }

walker W {
    has base: int = 0;
    has either: int = 0;
    can on_base with Base entry {
        self.base = self.base + here.val;
    }
    can on_either with (Sub, Other) entry {
        self.either = self.either + here.val;
    }
}

def subtype_dispatch_py() -> dict[str, any] {
    w = W();
    w spawn Sub(val=5);
    w spawn Other(val=7);
    return {"base": w.base, "either": w.either};
}

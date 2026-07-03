# Native fixture: str(float) must produce CPython's shortest round-trip repr
# (#6978 Phase 0.3) -- replaces the lossy %g. `frepr(x)` returns str(x) so the
# test can assert byte-equality against Python's repr() across many doubles
# (including the inf/nan spellings passed in from the host).

def frepr(x: float) -> str { return str(x); }

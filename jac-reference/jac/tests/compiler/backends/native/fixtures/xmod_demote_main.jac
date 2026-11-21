"""Fixture: a lowered importer with one call into a demoted cross-module callee.

`call_seam` calls `pyonly_len`, which demotes in `xmod_demote_lib.jac`; the
caller must demote in cascade with a reason naming the callee, never link
against the renamed symbol. `call_clean` and the entry stay natively lowered.
"""

import from xmod_demote_lib { clean_add, pyonly_len }

def call_seam(x: int) -> int {
    return pyonly_len(x) + 1;
}

def call_clean(x: int) -> int {
    return clean_add(x) + 1;
}

with entry {
    print(call_clean(2));
}

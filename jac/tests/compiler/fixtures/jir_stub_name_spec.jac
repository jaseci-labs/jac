"""Fixture exercising every AstSymbolStubNode subclass that needs a
fabricated name_spec on JIR round-trip.

Each top-level binding contains a literal that parses to an AstSymbolStubNode.
The JIR round-trip test loads this, writes to JIR, reads back, and asserts
name_spec is populated on every stub node — otherwise downstream symbol-
resolution passes crash with AttributeError on chain[0].sym.
"""

glob multi_str = "hello world";
glob f_str = f"value: {42}";
glob list_lit = [1, 2, 3];
glob set_lit = {1, 2, 3};
glob dict_lit = {"k": 1};
glob tuple_lit = (1, 2, 3);
glob list_compr = [x for x in [1, 2, 3]];
glob set_compr = {x for x in [1, 2, 3]};
glob dict_compr = {x: x for x in [1, 2, 3]};
glob slice_lit = list_lit[0:2];

"""Impl annex for issue #6794. The event ability (which uses `skip`) and the
driver are implemented HERE, split from their decls in osp_skip_annex.na.jac —
so the `skip` is enclosed by an `ImplDef` carrying an `EventSignature` (`with
Item entry`), not an inline `Ability`. The native capability check must treat
that the same as an inline event-ability `skip`.
"""

impl Collector.grab with Item entry {
    if here.val == 0 {
        skip;
    }
    self.total = self.total + here.val;
}

impl collect(a: int, b: int, c: int) -> int {
    w = Collector();
    w spawn Item(val=a);
    w spawn Item(val=b);
    w spawn Item(val=c);
    return w.total;
}

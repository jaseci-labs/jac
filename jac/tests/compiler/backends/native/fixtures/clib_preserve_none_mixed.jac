"""A preserve_none handler next to an ordinary C definition, both reading
memory through pointer views."""
import from c {
    obj Pair {
        has first: i64 = 0,
            second: i64 = 0;
    }  @__preserve_none
    def pn_hop(acc: ptr[i64], n: i64) -> i64 {
        return acc.view(1)[0] + ptr[Pair](acc).view(1)[0].second + n;
    }  def plain_entry(acc: ptr[i64], n: i64) -> i64 {
        return acc.view(1)[0] - n;
    }
}

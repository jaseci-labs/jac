"""Heterogeneous containers under headerless --gc none --enforce-nogc.

Jacval element slots carry no RC header, so container death must reclaim
boxed heap payloads through the stamped elem-drop slot: the drop walk hands
each live jacval slot to a tag-dispatched drop that frees string payloads
and ignores scalars. Every iteration stores a strdup'd string element (the
nogc element-prep copy) into a fresh mixed container and drops it; the only
thing that frees those copies is the jacval slot drop, so any skipped slot
shows up as per-iteration heap growth under the test's in-use probe, and a
drop that treated the slot as a raw pointer would free garbage from the
tag/payload words. The JIT harness drives the churn functions; the entry
block self-checks for the AOT run.
"""

def list_churn(n: int) -> int {
    i: int = 0;
    total: int = 0;
    while i < n {
        m: list = [i, "abcdef", 2.5];
        total = total + len(m[1]);
        i = i + 1;
    }
    return total;
}

def dict_churn(n: int) -> int {
    i: int = 0;
    total: int = 0;
    while i < n {
        d: dict = {"num": i, "tag": "abcdef"};
        total = total + len(d["tag"]);
        i = i + 1;
    }
    return total;
}

with entry {
    print(list_churn(200));
    print(dict_churn(200));
    print("done");
}

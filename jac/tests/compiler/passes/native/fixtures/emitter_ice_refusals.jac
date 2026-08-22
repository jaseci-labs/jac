"""Two emitter crashes that resisted a root fix and became named refusals.

Both raised a `TypeError` out of the IR builder, which the granular-demotion
layer reported as "native emitter error in", burying the real defect under a
stack trace. Neither construct is supported yet; the contract is that the
refusal says which operand did not line up.

`tuple_startswith` is `unitree.jac`'s `String.lit_value` accessor: CPython's
`str.startswith` takes a tuple of prefixes and the native emitter takes one
string, so the tuple reached `strlen`.

`arg_shape_mismatch` is `type_utils.collect_member_syms`: a call whose argument
lost its type upstream reached the callee with a value it cannot take, because
`_coerce_type` answers with the value unchanged when it has no coercion for a
pair.
"""

obj Holder {
    has n: int = 0;
}


def tuple_startswith(s: str) -> int {
    if s.startswith(("'", '"')) {
        return 1;
    }
    return 0;
}


def plain_startswith(s: str) -> int {
    if s.startswith("r") {
        return 1;
    }
    return 0;
}


def takes_holder(h: Holder) -> int {
    return h.n;
}


def arg_shape_mismatch(s: str) -> int {
    return takes_holder(s);
}

"""Companion module for `type_keyed_dict.jac`: classes it does not declare.

`ext_class` mints a class reference *here*, from `Ext`'s vtable, for a table
that is built and probed in the other module against a literal `Ext` /
`ExtSub` written there. Class identity in the native backend has to be
program-wide, so the two spellings must land on the same bucket.
"""

obj Ext {
    has v: int = 0;
}

obj ExtSub(Ext) {
    has w: int = 0;
}

"""The runtime class of `e`, resolved in this module."""
def ext_class(e: Ext) -> type {
    return `type(e);
}

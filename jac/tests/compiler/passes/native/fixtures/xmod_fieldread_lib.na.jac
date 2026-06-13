"""Native cross-module node-field fixture (issue #6659 Bug 1): the library
declares an OSP `node` archetype and a factory that constructs it. A local
`node` always reserves the OSP header (vtable@0, `__type_tag`@1), so `tag`
lands at field index 2 here. A consumer that merely reads `a.tag` (no
spawn/connect/visit) must lay the imported `Area` out IDENTICALLY or it reads
the wrong slot (the vtable pointer) and gets garbage."""

node Area { has tag: int = 0; }

def make_area() -> Area {
    return Area(tag=7);
}

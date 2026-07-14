"""Native cross-module node-field consumer (issue #6659 Bug 1): constructs the
imported `Area` via the library factory and reads `a.tag` directly -- NO
spawn/connect/visit, so the module does not "use OSP". The imported node must
still reserve its OSP header so its field offsets match the defining module;
otherwise `a.tag` reads the vtable slot and returns garbage. The same program on
the @sv pathway returns {"tag": 7}."""

import from xmod_fieldread_lib { Area, make_area }

def fieldread_na() -> dict[str, any] {
    a = make_area();
    return {"tag": a.tag};
}

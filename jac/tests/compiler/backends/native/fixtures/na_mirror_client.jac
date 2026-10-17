"""Server-codespace consumer of a natively-pinned module.

Everything here runs in the server tier: it constructs MirrorPoint, calls its
method, and calls an imported free function. With the pin from jac.toml
("na_mirror_target" = "native") the import must lower to pyb_mirror_member
splices instead of being dropped.
"""

import from na_mirror_target { MirrorPoint, mirror_double }

with entry {
    p = MirrorPoint(x=3, y=4);
    print(p.sum2(), mirror_double(21));
}

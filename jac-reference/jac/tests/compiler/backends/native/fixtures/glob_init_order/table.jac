"""A member table whose module imports back from its reader."""

import from holder { spec_name }

obj Member {
    has name: str,
        offset: int;
}

glob MEMBERS: list[Member] = [
         Member(name="handle", offset=0),
         Member(name="kind", offset=8),
         Member(name="maxvalue", offset=12)
     ];

def owner -> str {
    return spec_name() + ":" + str(len(MEMBERS));
}

"""Hierarchies the foreign-subclass checks run against.

`xmod_isinstance_foreign_check` imports only this module and tests against
`Actor`/`NActor`; `xmod_isinstance_foreign_leaf` subclasses `Player`/`NPlayer`
out of its sight -- and out of this module's, which matches class patterns
against its own `Actor` below.
"""

obj Thing {
    has name: str = "";
}

obj Actor(Thing) {
    has health: int = 100;
}

obj Player(Actor) {
    has speed: int = 1;
}

node NThing {
    has name: str = "";
}

node NActor(NThing) {
    has health: int = 100;
}

node NPlayer(NActor) {
    has speed: int = 1;
}

def foreign_match_actor(thing: Thing) -> int {
    match thing {
        case Actor(health = h):
            return (h as int);

        case _:
            return -1;

    }
}

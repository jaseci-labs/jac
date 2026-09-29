"""Subclasses `xmod_isinstance_foreign_check` never sees: `Bot` and `NBot`
derive from `Actor` through `Player`; `Prop` derives from `Thing` only."""

import from xmod_isinstance_foreign_base { Thing, Player, NThing, NPlayer }

obj Bot(Player) {
    has skill: int = 1;
}

obj Prop(Thing) {
    has mass: int = 1;
}

node NBot(NPlayer) {
    has skill: int = 1;
}

node NProp(NThing) {
    has mass: int = 1;
}

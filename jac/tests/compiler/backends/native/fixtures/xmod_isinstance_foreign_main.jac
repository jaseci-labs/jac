"""Builds instances of classes `xmod_isinstance_foreign_check` cannot see and
hands them to its checks. `k` picks the object: 0 a `Bot` (an `Actor` two
links up), 1 a `Prop` (a `Thing` that is no `Actor`), 2 a `Player` (a class
the check module does see)."""

import from xmod_isinstance_foreign_base {
    Thing,
    Actor,
    Player,
    NThing,
    NPlayer,
    foreign_match_actor
}
import from xmod_isinstance_foreign_leaf { Bot, Prop, NBot, NProp }
import from xmod_isinstance_foreign_check {
    foreign_is_actor,
    foreign_is_kind,
    foreign_node_is_actor
}

def foreign_pick(k: int) -> Thing {
    if k == 0 {
        return Bot(health=7);
    } elif k == 1 {
        return Prop();
    }
    return Player(health=9);
}

def foreign_node_pick(k: int) -> NThing {
    if k == 0 {
        return NBot();
    } elif k == 1 {
        return NProp();
    }
    return NPlayer();
}

def chk_foreign_isinstance(k: int) -> int {
    return foreign_is_actor(foreign_pick(k));
}

def chk_foreign_match(k: int) -> int {
    return foreign_match_actor(foreign_pick(k));
}

def chk_foreign_kind(k: int) -> int {
    return foreign_is_kind(foreign_pick(k), Actor);
}

def chk_foreign_walker(k: int) -> int {
    return foreign_node_is_actor(foreign_node_pick(k));
}

"""A declared endpoint is a promise the checker trusts, so it must be enforced."""
node Profile {
    has name: str = "";
}

node Tweet {
    has txt: str = "";
}

edge Post: Profile --> Tweet {}
edge Gradual: any --> any {}

def link_unproven(n: Node, t: Tweet) {
    n +>:Post:+> t;
}

def walk_unproven(n: Node) -> list[Tweet] {
    return [n->:Post:->];
}

with entry {
    a = Profile();
    t = Tweet();
    a +>:Post:+> t;
    ok_out = [a->:Post:->];
    ok_in = [t<-:Post:<-];
    t +>:Post:+> a;
    wrong_origin = [t->:Post:->];
    a +>:Gradual:+> t;
    gradual_ok = [a->:Gradual:->];
}

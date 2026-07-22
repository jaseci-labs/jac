"""Cross-backend OSP equivalence fixture: multi-hop typed-edge traversals.

The littleX shapes (#7626 B1): a chain of edge hops with per-step node
filters inside ONE edge reference. The graph is a tiny social feed --
`me -Follow-> p2/p3` (profiles), each profile posts a tweet, and `me` has
an unfollowed tweet hanging off it that the Profile filter must exclude:

    me  -Follow-> p2 --> t1(10)   (p2 also -Posted-> t1)
    me  -Follow-> p3 --> t2(20)
    me  --> t0(5)                 (not behind Follow, filtered by [?:Profile])

`feed` walks Follow then any-edge; `untyped` walks any-edge twice relying
on the [?:Profile] step filter; `typed2` uses a second typed hop (Posted)
so only p2's posted tweet survives. Backend status: py is the oracle; na
lowers the chain hop-by-hop through osp_refs + the tag filter kernel. The
body is duplicated per backend fn (fixture idiom) so each leg runs fully
in its own codespace.
"""

node Profile {
    has val: int;
}

node Tweet {
    has val: int;
}

edge Follow {}
edge Posted {}

def multi_hop_py -> dict[str, any] {
    me = Profile(val=1);
    p2 = Profile(val=2);
    p3 = Profile(val=3);
    t1 = Tweet(val=10);
    t2 = Tweet(val=20);
    t0 = Tweet(val=5);
    me +>:Follow():+> p2;
    me +>:Follow():+> p3;
    p2 ++> t1;
    p3 ++> t2;
    me ++> t0;
    p2 +>:Posted():+> t1;
    feed = [me->:Follow:->[?:Profile]-->[?:Tweet]];
    untyped = [me-->[?:Profile]-->[?:Tweet]];
    typed2 = [me->:Follow:->[?:Profile]->:Posted:->[?:Tweet]];
    feed_vals: list[int] = [];
    for t in feed {
        feed_vals.append(t.val);
    }
    untyped_vals: list[int] = [];
    for t in untyped {
        untyped_vals.append(t.val);
    }
    typed2_vals: list[int] = [];
    for t in typed2 {
        typed2_vals.append(t.val);
    }
    return {"feed": feed_vals, "untyped": untyped_vals, "typed2": typed2_vals};
}

na {
    def multi_hop_na -> dict[str, any] {
        me = Profile(val=1);
        p2 = Profile(val=2);
        p3 = Profile(val=3);
        t1 = Tweet(val=10);
        t2 = Tweet(val=20);
        t0 = Tweet(val=5);
        me +>:Follow():+> p2;
        me +>:Follow():+> p3;
        p2 ++> t1;
        p3 ++> t2;
        me ++> t0;
        p2 +>:Posted():+> t1;
        feed = [me->:Follow:->[?:Profile]-->[?:Tweet]];
        untyped = [me-->[?:Profile]-->[?:Tweet]];
        typed2 = [me->:Follow:->[?:Profile]->:Posted:->[?:Tweet]];
        feed_vals: list[int] = [];
        for t in feed {
            feed_vals.append(t.val);
        }
        untyped_vals: list[int] = [];
        for t in untyped {
            untyped_vals.append(t.val);
        }
        typed2_vals: list[int] = [];
        for t in typed2 {
            typed2_vals.append(t.val);
        }
        return {"feed": feed_vals, "untyped": untyped_vals, "typed2": typed2_vals};
    }
}

cl {
    def multi_hop_cl -> dict[str, any] {
        me = Profile(val=1);
        p2 = Profile(val=2);
        p3 = Profile(val=3);
        t1 = Tweet(val=10);
        t2 = Tweet(val=20);
        t0 = Tweet(val=5);
        me +>:Follow():+> p2;
        me +>:Follow():+> p3;
        p2 ++> t1;
        p3 ++> t2;
        me ++> t0;
        p2 +>:Posted():+> t1;
        feed = [me->:Follow:->[?:Profile]-->[?:Tweet]];
        untyped = [me-->[?:Profile]-->[?:Tweet]];
        typed2 = [me->:Follow:->[?:Profile]->:Posted:->[?:Tweet]];
        feed_vals: list[int] = [];
        for t in feed {
            feed_vals.append(t.val);
        }
        untyped_vals: list[int] = [];
        for t in untyped {
            untyped_vals.append(t.val);
        }
        typed2_vals: list[int] = [];
        for t in typed2 {
            typed2_vals.append(t.val);
        }
        return {"feed": feed_vals, "untyped": untyped_vals, "typed2": typed2_vals};
    }
}

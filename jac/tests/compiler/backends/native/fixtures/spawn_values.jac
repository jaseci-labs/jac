import from spawn_values_tree { Kid, Tree }
import from spawn_values_base { CompilerPass, Ctx, TreePass, run_passes, walk_any }
import from spawn_values_lib { Collect, Count, Once }

glob PASSES: tuple[type[CompilerPass], ...] = (Count, Once, TreePass);

def build_tree -> Tree {
    top = Tree(label="r");
    a = Tree(label="a");
    top +>:Kid:+> a;
    top +>:Kid:+> Tree(label="b");
    a +>:Kid:+> Tree(label="c");
    return top;
}

def gather(kind: type[CompilerPass], top: Tree) -> list[str] {
    walker_value = kind(module=top, ctx=Ctx(name=kind.__name__));
    top spawn walker_value;
    return [str(item) for item in walker_value.reports];
}

with entry {
    top = build_tree();
    for pass_type in PASSES {
        ctx = Ctx(name=pass_type.__name__);
        top spawn pass_type(module=top, ctx=ctx);
        print(ctx.name, " ".join(ctx.log));
    }
    for line in run_passes([Once, Count], top) {
        print(line);
    }
    print(" ".join(gather(Collect, top)));
    print(Count.__name__, len(gather(Once, top)));
    counter = Count(module=top, ctx=Ctx(name="any"));
    walk_any(top, counter);
    print(counter.ctx.name, counter.seen, type(counter).__name__);
}

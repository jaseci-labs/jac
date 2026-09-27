import from spawn_values_tree { Tree, TreeWalker }

obj Ctx {
    has name: str,
        log: list[str] = [];
}

walker CompilerPass {
    has ctx: Ctx,
        module: Tree;
}

walker TreePass(CompilerPass, TreeWalker) {
    can enter_walk with Tree entry {
        self.ctx.log.append("+" + here.label);
    }

    can exit_walk with Tree exit {
        self.ctx.log.append("-" + here.label);
    }
}

def run_passes(passes: list[type[CompilerPass]], top: Tree) -> list[str] {
    lines: list[str] = [];
    for pass_type in passes {
        ctx = Ctx(name=pass_type.__name__);
        top spawn pass_type(module=top, ctx=ctx);
        lines.append(ctx.name + " " + " ".join(ctx.log));
    }
    return lines;
}

def walk_any(top: Tree, walk: Walker) {
    top spawn walk;
}

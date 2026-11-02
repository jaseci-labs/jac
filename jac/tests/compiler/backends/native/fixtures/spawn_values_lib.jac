import from spawn_values_tree { Tree }
import from spawn_values_base { CompilerPass, TreePass }

walker Count(TreePass) {
    has seen: int = 0;

    can count with Tree entry {
        self.seen += 1;
        self.ctx.log.append(str(self.seen));
    }
}

walker Once(CompilerPass) {
    can hit with Tree entry {
        self.ctx.log.append("once:" + here.label);
    }
}

walker Collect(TreePass) {
    has prefix: str = "@";

    can gather with Tree entry {
        report self.prefix + here.label;
    }
}

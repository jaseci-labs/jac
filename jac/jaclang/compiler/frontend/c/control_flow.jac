"""Represent unstructured C control flow before emitting ordinary Jac statements."""
import jaclang.compiler.frontend.unitree as uni;
import from .jac_ast { CJacAst }

obj CFlowBlock {
    has body: list[uni.CodeBlockStmt] = [],
        target: int = -1,
        alternative: int = -1,
        condition: uni.Expr | None = None;
}

obj CSwitchTargets {
    has cases: list[tuple[int, int, int]] = [],
        default_target: int = -1;
}

obj CFlowGraph {
    has ast: CJacAst,
        state: str,
        blocks: list[CFlowBlock] = [],
        locals: list[uni.CodeBlockStmt] = [],
        labels: dict[str, int] = {},
        defined: set[str] = set();

    def block -> int {
        self.blocks.append(CFlowBlock());
        return len(self.blocks) - 1;
    }

    def label(name: str) -> int {
        if name not in self.labels { self.labels[name] = self.block(); }
        return self.labels[name];
    }

    def jump(source: int, target: int) {
        self.blocks[source].target = target;
    }

    def branch(source: int, condition: uni.Expr, target: int, alternative: int) {
        block = self.blocks[source];
        block.condition = condition;
        block.target = target;
        block.alternative = alternative;
    }

    def transition(target: int) -> list[uni.CodeBlockStmt] {
        if target < 0 { return [self.ast.control("break")]; }
        return [self.ast.assignment(self.state, self.ast.call("i32", [self.ast.integer(target)])),
            self.ast.control("continue")];
    }

    def emit(start_block: int) -> list[uni.CodeBlockStmt] {
        missing = set(self.labels) - self.defined;
        if missing { raise ValueError("Undefined C labels: " + ", ".join(sorted(missing))); }
        # Only reachable blocks need source. Lexical declarations were resolved
        # before this walk, including declarations bypassed by a jump.
        reachable: set[int] = set(); pending = [start_block];
        while pending {
            index = pending.pop();
            if index < 0 or index in reachable { continue; }
            reachable.add(index); block = self.blocks[index];
            pending.append(block.target);
            if block.condition is not None { pending.append(block.alternative); }
        }
        body: list[uni.CodeBlockStmt] = [];
        for index in sorted(reachable) {
            block = self.blocks[index]; statements = list(block.body);
            condition = block.condition;
            if condition is not None {
                statements.append(self.ast.branch(condition, self.transition(block.target),
                    self.transition(block.alternative)));
            } else { statements.extend(self.transition(block.target)); }
            body.append(self.ast.branch(self.ast.binary("==", self.ast.name(self.state),
                self.ast.call("i32", [self.ast.integer(index)])), statements));
        }
        body.append(self.ast.control("break"));
        return self.locals + [self.ast.assignment(self.state,
            self.ast.call("i32", [self.ast.integer(start_block)]), "i32"),
            self.ast.loop(self.ast.boolean(True), body)];
    }
}

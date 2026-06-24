import from jaclang.compiler.passes.native.llvm.ir { CallInstr }
class Visitor(object) {
    def `visit(self: Visitor, module: Any) -> object {
        self._module = module;
        for func in module.functions {
            self.visit_Function(func);
        }
    }
    def visit_Function(self: Visitor, func: Any) -> object {
        self._function = func;
        for bb in func.blocks {
            self.visit_BasicBlock(bb);
        }
    }
    def visit_BasicBlock(self: Visitor, bb: Any) -> object {
        self._basic_block = bb;
        for instr in bb.instructions {
            self.visit_Instruction(instr);
        }
    }
    def visit_Instruction(self: Visitor, instr: Any) -> object {
        raise NotImplementedError;
    }
    @property
    def module(self: Visitor) -> object {
        return self._module;
    }
    @property
    def function(self: Visitor) -> object {
        return self._function;
    }
    @property
    def basic_block(self: Visitor) -> object {
        return self._basic_block;
    }
}
class CallVisitor(Visitor) {
    def visit_Instruction(self: CallVisitor, instr: Any) -> object {
        if isinstance(instr, CallInstr) {
            self.visit_Call(instr);
        }
    }
    def visit_Call(self: CallVisitor, instr: Any) -> object {
        raise NotImplementedError;
    }
}
class ReplaceCalls(CallVisitor) {
    def init(self: ReplaceCalls, orig: Any, repl: Any) -> object {
        super.init();
        self.orig = orig;
        self.repl = repl;
        self.calls = [];
    }
    def visit_Call(self: ReplaceCalls, instr: Any) -> object {
        if (instr.callee == self.orig) {
            instr.replace_callee(self.repl);
            self.calls.append(instr);
        }
    }
}
"""Replace all calls to `orig` to `repl` in module `mod`.
    Returns the references to the returned calls
    """
def replace_all_calls(mod: Any, orig: Any, repl: Any) -> object {
    rc = ReplaceCalls(orig, repl);
    rc.visit(mod);
    return rc.calls;
}


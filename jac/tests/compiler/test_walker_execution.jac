"""Constructing a compiler walker no longer executes the pass."""
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.passes.context { CompileContext }
import from jaclang.compiler.passes.freeze_structure_pass { FreezeStructurePass }

test "constructing a pass leaves the tree untouched until spawn" {
    prog = JacProgram();
    mod = prog.parse_str("with entry { x = 1; }", "walker_spawn.jac");
    ctx = CompileContext(
        current_node=mod, from_pass=FreezeStructurePass, pass_name="FreezeStructurePass"
    );
    walk = FreezeStructurePass(module=mod, ctx=ctx);
    assert not mod._struct_frozen;
    mod spawn walk;
    assert all(nd._struct_frozen for nd in mod.flatten());
}

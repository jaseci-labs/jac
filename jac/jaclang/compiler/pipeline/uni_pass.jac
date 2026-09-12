import from jaclang.compiler.ir.schema { Module, TreeWalker, UniNode }
import from jaclang.compiler.pipeline.pass_base { Transform }
import from jaclang.runtime.osp_kernel { osp_skip_rest }

walker UniPass(Transform, TreeWalker) {
    has ir_in: Module;

    can enter_walk with UniNode entry;
    can exit_walk with UniNode exit;
    def postinit -> None;
    def before_pass -> None;
    def after_pass -> None;
    def recalculate_parents(nd: UniNode) -> None;
    def transform(ir_in: Module) -> Module;
    def traverse(nd: UniNode) -> UniNode;
}

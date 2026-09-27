import from jaclang.compiler.frontend.roles { Kid }
import from jaclang.compiler.passes.context { CompileContext, CompilerPass }
import jaclang.compiler.frontend.unitree as uni;
import from jaclang.compiler.frontend.codeinfo { NodeComments }

walker CommentAttachPass(CompilerPass) {
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
    def _node_comments(nd: uni.UniNode) -> NodeComments;
    def _attach_trailing_own(tok: uni.Token, comment: uni.CommentToken) -> None;
    def _largest_ending_at(tok: uni.Token) -> uni.UniNode;
    def _largest_starting_at(tok: uni.Token) -> uni.UniNode;
}

import from jaclang.compiler.backends.common.artifact_store { artifact_for }
import from bisect { bisect_left }
import from jaclang.compiler.ir.enums { Tokens as Tok }
import jaclang.compiler.ir.schema as uni;
import from jaclang.compiler.backends.common.artifacts { NodeComments }
import from jaclang.compiler.pipeline.pass_base { Transform }

walker CommentAttachPass(Transform) {
    def transform(ir_in: uni.Module) -> uni.Module;
    def _run_impl(ir_in: uni.Module) -> uni.Module;
    can run_walk with uni.Module entry;
    def _node_comments(nd: uni.UniNode) -> NodeComments;
    def _attach_trailing_own(tok: uni.Token, comment: uni.CommentToken) -> None;
    def _largest_ending_at(tok: uni.Token) -> uni.UniNode;
    def _largest_starting_at(tok: uni.Token) -> uni.UniNode;
}

glob _CLOSING_DELIMS = [Tok.RBRACE, Tok.RPAREN, Tok.RSQUARE],
     _OPENING_DELIMS = [Tok.LBRACE, Tok.LPAREN, Tok.LSQUARE];

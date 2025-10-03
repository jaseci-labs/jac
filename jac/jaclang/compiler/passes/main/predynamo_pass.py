"""Pytorch Fix Pass."""

import ast as ast3
from typing import Optional, TypeVar, cast

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes import UniPass


T = TypeVar("T", bound=ast3.AST)


class PreDynamoPass(UniPass):
    """Pre-Dynamo pass for PyTorch."""

    def enter_node(self, node: uni.UniNode) -> None:
        """Enter node."""
        super().enter_node(node)

    def exit_node(self, node: uni.UniNode) -> None:
        """Exit node."""
        super().exit_node(node)

    def gen_name(self, node: uni.UniNode, name: Tok, value: str) -> uni.Name:
        """Generate Name."""
        return uni.Name(
            name=name,
            value=value,
            orig_src=node.loc.orig_src,
            col_start=node.loc.col_start,
            col_end=0,
            line=node.loc.first_line,
            end_line=node.loc.last_line,
            pos_start=0,
            pos_end=0,
        )

    def replace_node(
        self,
        new_nodes: list[uni.UniNode] | uni.UniNode,
        old_node: uni.UniNode,
        attr: str,
    ) -> None:
        """Replace old node with new nodes in parent's body and kid lists."""
        parent = old_node.parent
        if isinstance(new_nodes, uni.UniNode):
            new_nodes.parent = parent
            if hasattr(parent, attr):
                lst = getattr(parent, attr)
                if old_node in lst:
                    idx = lst.index(old_node)
                    lst[idx] = new_nodes
            if hasattr(parent, "kid") and old_node in parent.kid:
                idx = parent.kid.index(old_node)
                parent.kid[idx] = new_nodes
        else:  # list of nodes
            for n in new_nodes:
                n.parent = parent
            if hasattr(parent, attr):
                lst = getattr(parent, attr)
                if old_node in lst:
                    idx = lst.index(old_node)
                    setattr(parent, attr, lst[:idx] + new_nodes + lst[idx + 1 :])
            if hasattr(parent, "kid") and old_node in parent.kid:
                idx = parent.kid.index(old_node)
                parent.kid = parent.kid[:idx] + new_nodes + parent.kid[idx + 1 :]

    def check_same_lhs(
        self, assign_a: uni.UniNode, assign_b: uni.UniNode
    ) -> Optional[uni.Name]:
        """Return the common LHS target if both are simple assignment with same target."""
        if not (
            isinstance(assign_a, uni.Assignment)
            and isinstance(assign_b, uni.Assignment)
        ):
            return None
        ta, tb = assign_a.target[0], assign_b.target[0]
        if not (isinstance(ta, uni.Name) and isinstance(tb, uni.Name)):
            return None
        if ta.value != tb.value:
            return None
        return ta  # common target

    def check_call(self, node: uni.ExprStmt) -> Optional[tuple]:
        """Return (target, name, tensor_expr, kwargs) if node is target(name, tensor_expr, **kwargs)."""
        if isinstance(node, uni.ExprStmt) and isinstance(node.expr, uni.FuncCall):
            call = node.expr
            if (
                isinstance(call.target, uni.AtomTrailer)
                and len(call.params) >= 2
                and isinstance(call.params[0], (uni.String, uni.MultiString))
                and isinstance(call.params[1], uni.Expr)
            ):
                name = (
                    call.params[0]
                    if isinstance(call.params[0], uni.String)
                    else call.params[0].strings[0]
                )
                tensor_expr = call.params[1]
                kwargs = (
                    {
                        kw.key._sym_name: kw.value
                        for kw in call.params[2:]
                        if isinstance(kw, uni.KWPair)
                    }
                    if len(call.params) > 2
                    else {}
                )
                return (call.target, name, tensor_expr, kwargs)
        return None

    def exit_if_stmt(self, node: uni.IfStmt) -> None:
        """Exit if statement."""
        a0 = node.body[0]
        new_node = None
        if node.else_body:
            b0 = node.else_body.body[0]
        else:
            return
        if isinstance(a0, uni.Assignment) and isinstance(b0, uni.Assignment):
            lhs = self.check_same_lhs(a0, b0)
            if lhs is not None:
                func_name = self.gen_name(node, Tok.NAME, "torch")
                attr_name = self.gen_name(node, Tok.NAME, "where")
                target = uni.AtomTrailer(
                    target=func_name,
                    right=attr_name,
                    is_attr=True,
                    is_null_ok=False,
                    kid=[func_name, attr_name],
                )
                call = uni.FuncCall(
                    target=target,
                    params=[
                        node.condition,
                        cast(uni.Expr, a0.value),
                        cast(uni.Expr, b0.value),
                    ],
                    genai_call=None,
                    kid=[target, node.condition, a0, b0],
                )
                new_node = uni.Assignment(
                    target=[lhs], value=call, type_tag=None, kid=[lhs, call]
                )
                self.replace_node(new_node, node, "body")

        elif isinstance(a0, uni.ReturnStmt) and isinstance(b0, uni.ReturnStmt):
            aexpr, bexpr = a0.expr, b0.expr
            if aexpr is None or bexpr is None:
                return
            func_name = self.gen_name(node, Tok.NAME, "torch")
            attr_name = self.gen_name(node, Tok.NAME, "where")
            target = uni.AtomTrailer(
                target=func_name,
                right=attr_name,
                is_attr=True,
                is_null_ok=False,
                kid=[func_name, attr_name],
            )
            call = uni.FuncCall(
                target=target,
                params=[node.condition, cast(uni.Expr, aexpr), cast(uni.Expr, bexpr)],
                genai_call=None,
                kid=[target, node.condition, a0, b0],
            )
            new_node = uni.ReturnStmt(expr=call, kid=[call])
            self.replace_node(new_node, node, "body")

        elif isinstance(a0, uni.ExprStmt) and isinstance(b0, uni.ExprStmt):
            a_reg = self.check_call(a0)
            b_reg = self.check_call(b0)
            if a_reg is not None and b_reg is not None:
                a_target, a_name, a_expr, a_kwargs = a_reg
                b_target, b_name, b_expr, b_kwargs = b_reg
                if a_name.value == b_name.value and set(a_kwargs.keys()) == set(
                    b_kwargs.keys()
                ):
                    tmp_name = self.gen_name(node, Tok.NAME, f"__{eval(a_name.value)}")
                    tmp_name.py_ctx_func = ast3.Store
                    func_name = self.gen_name(node, Tok.NAME, "torch")
                    attr_name = self.gen_name(node, Tok.NAME, "where")
                    target = uni.AtomTrailer(
                        target=func_name,
                        right=attr_name,
                        is_attr=True,
                        is_null_ok=False,
                        kid=[func_name, attr_name],
                    )
                    call = uni.FuncCall(
                        target=target,
                        params=[node.condition, a_expr, b_expr],
                        genai_call=None,
                        kid=[target, node.condition, a_expr, b_expr],
                    )
                    assign_node = uni.Assignment(
                        target=[tmp_name],
                        value=call,
                        type_tag=None,
                        kid=[tmp_name, call],
                    )

                    kwargs_nodes = [
                        uni.KWPair(
                            name := self.gen_name(node, Tok.NAME, k), v, [name, v]
                        )
                        for k, v in a_kwargs.items()
                    ]
                    param_name = self.gen_name(
                        node, Tok.NAME, f"__{eval(a_name.value)}"
                    )
                    reg_call = uni.FuncCall(
                        target=a_target,
                        params=[a_name, param_name] + kwargs_nodes,
                        genai_call=None,
                        kid=[a_target, a_name, param_name] + kwargs_nodes,
                    )
                    reg_node = uni.ExprStmt(
                        expr=reg_call, in_fstring=False, kid=[reg_call]
                    )
                    self.replace_node([assign_node, reg_node], node, "body")

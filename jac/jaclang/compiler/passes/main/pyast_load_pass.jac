"""Python AST to Jac AST Conversion Pass for the Jac compiler.\n\nThis pass transforms Python AST nodes into equivalent Jac AST nodes by:\n\n1. Converting Python modules, classes, functions, and expressions to their Jac equivalents\n2. Preserving source location information and symbol relationships\n3. Handling Python-specific constructs and adapting them to Jac's object model\n4. Supporting both standard Python modules and type stub (.pyi) files\n5. Creating appropriate symbol tables and scopes for the converted nodes\n\nThis pass is crucial for Python interoperability, allowing Python code to be imported\nand used within Jac programs while maintaining type information and semantic relationships.\n"""
import from __future__ { annotations }
import ast as py_ast;
import os;
import re;
import from collections.abc { Sequence }
import from threading { Event }
import from typing { TYPE_CHECKING, TypeAlias, TypeVar, cast }
import jaclang.pycore.unitree as uni;
import from jaclang.pycore.constant { Tokens as Tok }
import from jaclang.pycore.passes.uni_pass { Transform }

with entry {
    if TYPE_CHECKING {
        import from jaclang.pycore.program { JacProgram }
    }
}

glob T = TypeVar('T', bound=uni.UniNode);

"""Jac Parser."""
class PyastBuildPass(Transform[(uni.PythonModuleAst, uni.Module)]) {
    """Initialize parser."""
    def init(
        self: PyastBuildPass,
        ir_in: uni.PythonModuleAst,
        prog: JacProgram,
        cancel_token: (Event | None) = None
    ) -> None {
        self.mod_path = ir_in.loc.mod_path;
        self.orig_src = ir_in.loc.orig_src;
        self.in_type_annotation = False;
        self.in_match_pattern = False;
        self.in_fstring_expr = False;
        Transform.init(self, ir_in=ir_in, prog=prog, cancel_token=cancel_token);
    }

    """Update node."""
    def nu(self: PyastBuildPass, <>node: T) -> T {
        self.cur_node = <>node;
        return <>node;
    }

    """Get python node type."""
    def convert(self: PyastBuildPass, <>node: py_ast.AST) -> uni.UniNode {
        import from jaclang.pycore.helpers { pascal_to_snake }
        if self.is_canceled() {
            raise StopIteration ;
        }
        if hasattr(self, f"proc_{pascal_to_snake(type(node).__name__)}") {
            ret = getattr(self, f"proc_{pascal_to_snake(type(node).__name__)}")(<>node);
        } else {
            raise self.ice(f"Unknown node type {type(node).__name__}") ;
        }
        return ret;
    }

    """Transform input IR."""
    def transform(self: PyastBuildPass, ir_in: uni.PythonModuleAst) -> uni.Module {
        self.ir_out: uni.Module = self.proc_module(ir_in.ast);
        return self.ir_out;
    }

    """Extract with entry from a body."""
    def extract_with_entry(
        self: PyastBuildPass, body: list[uni.UniNode], exclude_types: TypeAlias = T
    ) -> list[(T | uni.ModuleCode)] {
        def gen_mod_code(with_entry_body: list[uni.CodeBlockStmt]) -> uni.ModuleCode {
            return uni.ModuleCode(
                name=None, body=with_entry_body, kid=with_entry_body, doc=None
            );
        }
        extracted: list[(T | uni.ModuleCode)] = [];
        with_entry_body: list[uni.CodeBlockStmt] = [];
        for i in body {
            if isinstance(i, exclude_types) {
                if len(with_entry_body) {
                    extracted.append(gen_mod_code(with_entry_body));
                    with_entry_body = [];
                }
                extracted.append(i);
            } elif isinstance(i, uni.CodeBlockStmt) {
                if (isinstance(i, uni.ExprStmt) and isinstance(i.expr, uni.String)) {
                    self.convert_to_doc(i.expr);
                }
                with_entry_body.append(i);
            } else {
                continue;
            }
        }
        if len(with_entry_body) {
            extracted.append(gen_mod_code(with_entry_body));
        }
        return extracted;
    }

    """Process python node.\n\n        class Module(mod):\n            __match_args__ = ("body", "type_ignores")\n            body: list[stmt]\n            type_ignores: list[TypeIgnore]\n        """
    def proc_module(self: PyastBuildPass, <>node: py_ast.Module) -> uni.Module {
        if not <>node.body {
            return uni.Module.make_stub(inject_src=self.ir_in.orig_src);
        }
        elements: list[uni.UniNode] = [self.convert(i) for i in <>node.body];
        elements[0] = elements[0].expr
        if (
            isinstance(elements[0], uni.ExprStmt)
            and isinstance(elements[0].expr, uni.String)
        )
        else elements[0];
        doc_str_list = [elements[0]] if isinstance(elements[0], uni.String) else [];
        valid = (
            doc_str_list + self.extract_with_entry(
                elements[1:], (uni.ElementStmt, uni.EmptyToken)
            )
        )
        if doc_str_list
        else self.extract_with_entry(elements[:], (uni.ElementStmt, uni.EmptyToken));
        doc_str = elements[0] if isinstance(elements[0], uni.String) else None;
        self.convert_to_doc(doc_str) if doc_str else None;
        ret = uni.Module(
            name=self.mod_path.split(os.path.sep)[-1].split('.')[0],
            source=uni.Source('', mod_path=self.mod_path),
            doc=doc_str,
            body=valid[1:] if (valid and isinstance(valid[0], uni.String)) else valid,
            terminals=[],
            kid=valid
        );
        ret.is_raised_from_py = True;
        return self.nu(ret);
    }

    """Process python node.\n\n        class FunctionDef(stmt):\n            name: _Identifier\n            args: arguments\n            body: list[stmt]\n            decorator_list: list[expr]\n            returns: expr | None\n            if sys.version_info >= (3, 12):\n            type_params: list[type_param]\n        """
    def proc_function_def(
        self: PyastBuildPass, <>node: (py_ast.FunctionDef | py_ast.AsyncFunctionDef)
    ) -> uni.Ability {
        import from jaclang.pycore.jac_parser { TOKEN_MAP }
        reserved_keywords = [v for (_, v) in TOKEN_MAP.items()];
        name = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value=<>node.name,
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(<>node.name)),
            pos_start=0,
            pos_end=0,
            is_kwesc=(<>node.name in reserved_keywords)
        );
        body = [self.convert(i) for i in <>node.body];
        valid = [
            i
            for i in body
            if isinstance(i, uni.CodeBlockStmt)
        ];
        if (len(valid) != len(body)) {
            raise self.ice('Length mismatch in function body') ;
        }
        if (
            len(valid)
            and isinstance(valid[0], uni.ExprStmt)
            and isinstance(valid[0].expr, uni.String)
        ) {
            self.convert_to_doc(valid[0].expr);
            doc = valid[0].expr;
            valid_body = valid[1:];
        } else {
            doc = None;
            valid_body = valid;
        }
        decorators = [self.convert(i) for i in <>node.decorator_list];
        valid_dec = [
            i
            for i in decorators
            if isinstance(i, uni.Expr)
        ];
        if (len(valid_dec) != len(decorators)) {
            raise self.ice('Length mismatch in decorators on function') ;
        }
        valid_decorators = valid_dec if valid_dec else None;
        res = self.convert(<>node.args);
        sig: (uni.FuncSignature | None) = res
        if isinstance(res, uni.FuncSignature)
        else None;
        self.in_type_annotation = True;
        ret_sig = self.convert(<>node.returns) if <>node.returns else None;
        self.in_type_annotation = False;
        if isinstance(ret_sig, uni.Expr) {
            if not sig {
                sig = uni.FuncSignature(
                    posonly_params=[],
                    params=[],
                    varargs=None,
                    kwonlyargs=[],
                    kwargs=None,
                    return_type=ret_sig,
                    kid=[ret_sig]
                );
            } else {
                sig.return_type = ret_sig;
                sig.add_kids_right([sig.return_type]);
            }
        }
        kid = (
            ([doc] if doc else []) + (
                [name, sig, *valid_body] if sig else [name, *valid_body]
            )
        );
        if not sig {
            raise self.ice('Function signature not found') ;
        }
        ret = uni.Ability(
            name_ref=name,
            is_async=False,
            is_static=False,
            is_abstract=False,
            is_override=False,
            access=None,
            signature=sig,
            body=valid_body,
            decorators=valid_decorators,
            doc=doc,
            kid=kid
        );
        return ret;
    }

    """Process python node.\n\n        class AsyncFunctionDef(stmt):\n            __match_args__ = ("name", "args", "body", "decorator_list",\n                              "returns", "type_comment", "type_params")\n            name: _Identifier\n            args: arguments\n            body: list[stmt]\n            decorator_list: list[expr]\n            returns: expr | None\n            if sys.version_info >= (3, 12):\n                type_params: list[type_param]\n        """
    def proc_async_function_def(
        self: PyastBuildPass, <>node: py_ast.AsyncFunctionDef
    ) -> uni.Ability {
        ability = self.proc_function_def(<>node);
        ability.is_async = True;
        return ability;
    }

    """Process python node.\n\n        class ClassDef(stmt):\n            __match_args__ = ("name", "bases", "keywords", "body",\n                              "decorator_list", "type_params")\n            name: _Identifier\n            bases: list[expr]\n            keywords: list[keyword]\n            body: list[stmt]\n            decorator_list: list[expr]\n            if sys.version_info >= (3, 12):\n            type_params: list[type_param]\n        """
    def proc_class_def(
        self: PyastBuildPass, <>node: py_ast.ClassDef
    ) -> (uni.Archetype | uni.Enum) {
        name = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value=<>node.name,
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(<>node.name)),
            pos_start=0,
            pos_end=0
        );
        arch_type = uni.Token(
            orig_src=self.orig_src,
            name=Tok.KW_CLASS,
            value='class',
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0
        );
        body = [self.convert(i) for i in <>node.body];
        for body_stmt in body {
            if (
                isinstance(body_stmt, uni.Ability)
                and isinstance(body_stmt.name_ref, uni.Name)
                and (body_stmt.name_ref.value == '__init__')
            ) {
                tok = uni.Name(
                    orig_src=self.orig_src,
                    name=Tok.KW_INIT,
                    value='init',
                    line=<>node.lineno,
                    end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                    col_start=<>node.col_offset,
                    col_end=(<>node.col_offset + len('init')),
                    pos_start=0,
                    pos_end=0
                );
                body_stmt.name_ref = uni.SpecialVarRef(var=tok);
            }
            if (
                isinstance(body_stmt, uni.Ability)
                and body_stmt.signature
                and isinstance(body_stmt.signature, uni.FuncSignature)
                and body_stmt.signature.params
            ) {
                for param in body_stmt.signature.params {
                    if (
                        (param.name.value == 'self')
                        and param.type_tag
                        and isinstance(param.type_tag.tag, uni.Name)
                    ) {
                        param.type_tag.tag.value = name.value;
                    }
                }
            }
        }
        doc = body[0].expr
        if (isinstance(body[0], uni.ExprStmt) and isinstance(body[0].expr, uni.String))
        else None;
        self.convert_to_doc(doc) if doc else None;
        body = body[1:] if doc else body;
        valid: list[uni.ArchBlockStmt] = self.extract_with_entry(
            body, uni.ArchBlockStmt
        )
        if (body and not (isinstance(body[0], uni.Semi) and (len(body) == 1)))
        else [];
        empty_block: Sequence[uni.UniNode] = [
            self.operator(Tok.LBRACE, '{'),
            self.operator(Tok.RBRACE, '}')
        ];
        valid_body = valid if valid else empty_block;
        converted_base_classes = [self.convert(base) for base in <>node.bases];
        base_classes: list[uni.Expr] = [
            base
            for base in converted_base_classes
            if isinstance(base, uni.Expr)
        ];
        converted_decorators_list = [self.convert(i) for i in <>node.decorator_list];
        decorators = [
            i
            for i in converted_decorators_list
            if isinstance(i, uni.Expr)
        ];
        if (len(decorators) != len(converted_decorators_list)) {
            raise self.ice('Length mismatch in decorators on class') ;
        }
        valid_decorators = decorators if decorators else None;
        kid = [name, *base_classes, *valid_body, doc]
        if (doc and base_classes)
        else [name, *base_classes, *valid_body]
        if base_classes
        else [name, *valid_body, doc] if doc else [name, *valid_body];
        return uni.Archetype(
            arch_type=arch_type,
            name=name,
            access=None,
            base_classes=base_classes,
            body=valid,
            kid=kid,
            doc=doc,
            decorators=valid_decorators
        );
    }

    """Process python node.\n\n        class Return(stmt):\n            __match_args__ = ("value",)\n            value: expr | None\n        """
    def proc_return(
        self: PyastBuildPass, <>node: py_ast.Return
    ) -> (uni.ReturnStmt | None) {
        value = self.convert(<>node.value) if <>node.value else None;
        if not value {
            return uni.ReturnStmt(
                expr=None, kid=[self.operator(Tok.KW_RETURN, 'return')]
            );
        } elif (value and isinstance(value, uni.Expr)) {
            return uni.ReturnStmt(expr=value, kid=[value]);
        } else {
            raise self.ice('Invalid return value') ;
        }
    }

    """Process python node.\n\n        class Delete(stmt):\n            __match_args__ = ("targets",)\n            targets: list[expr]\n        """
    def proc_delete(self: PyastBuildPass, <>node: py_ast.Delete) -> uni.DeleteStmt {
        exprs = [self.convert(target) for target in <>node.targets];
        valid_exprs = [
            expr
            for expr in exprs
            if isinstance(expr, uni.Expr)
        ];
        if (not len(valid_exprs) or (len(valid_exprs) != len(exprs))) {
            raise self.ice('Length mismatch in delete targets') ;
        }
        target_1 = valid_exprs[0]
        if (len(valid_exprs) > 1)
        else uni.TupleVal(values=valid_exprs, kid=[*valid_exprs]);
        return uni.DeleteStmt(target=target_1, kid=[*valid_exprs]);
    }

    """Process python node.\n\n        class Assign(stmt):\n            targets: list[expr]\n            value: expr\n        """
    def proc_assign(self: PyastBuildPass, <>node: py_ast.Assign) -> uni.Assignment {
        value = self.convert(<>node.value);
        targets = [self.convert(target) for target in <>node.targets];
        valid = [
            target
            for target in targets
            if isinstance(target, uni.Expr)
        ];
        if not (len(valid) == len(targets)) {
            raise self.ice('Length mismatch in assignment targets') ;
        }
        if isinstance(value, uni.Expr) {
            return uni.Assignment(
                target=valid,
                value=value,
                type_tag=None,
                mutable=False,
                kid=[*valid, value]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class AugAssign(stmt):\n            __match_args__ = ("target", "op", "value")\n            target: Name | Attribute | Subscript\n            op: operator\n            value: expr\n        """
    def proc_aug_assign(
        self: PyastBuildPass, <>node: py_ast.AugAssign
    ) -> uni.Assignment {
        import from jaclang.pycore.jac_parser { TOKEN_MAP }
        target = self.convert(<>node.target);
        op = self.convert(<>node.op);
        if isinstance(op, uni.Token) {
            op.name = self.aug_op_map(TOKEN_MAP, op);
        }
        value = self.convert(<>node.value);
        if (
            isinstance(value, uni.Expr)
            and isinstance(target, uni.Expr)
            and isinstance(op, uni.Token)
        ) {
            return uni.Assignment(
                target=[target],
                type_tag=None,
                mutable=False,
                aug_op=op,
                value=value,
                kid=[target, op, value]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class AnnAssign(stmt):\n            __match_args__ = ("target", "annotation", "value", "simple")\n            target: Name | Attribute | Subscript\n            annotation: expr\n            value: expr | None\n            simple: int\n        """
    def proc_ann_assign(
        self: PyastBuildPass, <>node: py_ast.AnnAssign
    ) -> uni.Assignment {
        target = self.convert(<>node.target);
        self.in_type_annotation = True;
        annotation = self.convert(<>node.annotation);
        self.in_type_annotation = False;
        if isinstance(annotation, uni.Expr) {
            annotation_subtag = uni.SubTag[uni.Expr](tag=annotation, kid=[annotation]);
        } else {
            raise self.ice() ;
        }
        value = self.convert(<>node.value) if <>node.value else None;
        if (
            (isinstance(value, (uni.Expr, uni.YieldExpr)) or not value)
            and isinstance(annotation, uni.Expr)
            and isinstance(target, uni.Expr)
        ) {
            return uni.Assignment(
                target=[target],
                value=value if isinstance(value, (uni.Expr, uni.YieldExpr)) else None,
                type_tag=annotation_subtag,
                mutable=False,
                kid=[target, annotation_subtag, value]
                if value
                else [target, annotation_subtag]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class For(stmt):\n            __match_args__ = ("target", "iter", "body", "orelse")\n            target: expr\n            iter: expr\n            body: list[stmt]\n            orelse: list[stmt]\n        """
    def proc_for(self: PyastBuildPass, <>node: py_ast.For) -> uni.InForStmt {
        target = self.convert(<>node.target);
        iter = self.convert(<>node.iter);
        body = [self.convert(i) for i in <>node.body];
        val_body = [
            i
            for i in body
            if isinstance(i, uni.CodeBlockStmt)
        ];
        if (len(val_body) != len(body)) {
            raise self.ice('Length mismatch in for body') ;
        }
        valid_body = val_body;
        orelse = [self.convert(i) for i in <>node.orelse];
        val_orelse = [
            i
            for i in orelse
            if isinstance(i, uni.CodeBlockStmt)
        ];
        if (len(val_orelse) != len(orelse)) {
            raise self.ice('Length mismatch in for orelse') ;
        }
        fin_orelse = uni.ElseStmt(body=val_orelse, kid=val_orelse) if orelse else None;
        if (isinstance(target, uni.Expr) and isinstance(iter, uni.Expr)) {
            return uni.InForStmt(
                target=target,
                is_async=False,
                collection=iter,
                body=valid_body,
                else_body=fin_orelse,
                kid=[target, iter, *valid_body, fin_orelse]
                if fin_orelse
                else [target, iter, *valid_body]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process AsyncFor node.\n\n        class AsyncFor(stmt):\n            __match_args__ = ("target", "iter", "body", "orelse")\n            target: expr\n            iter: expr\n            body: list[stmt]\n            orelse: list[stmt]`\n        """
    def proc_async_for(self: PyastBuildPass, <>node: py_ast.AsyncFor) -> uni.InForStmt {
        target = self.convert(<>node.target);
        iter = self.convert(<>node.iter);
        body = [self.convert(i) for i in <>node.body];
        val_body = [
            i
            for i in body
            if isinstance(i, uni.CodeBlockStmt)
        ];
        if (len(val_body) != len(body)) {
            raise self.ice('Length mismatch in for body') ;
        }
        valid_body = val_body;
        orelse = [self.convert(i) for i in <>node.orelse];
        val_orelse = [
            i
            for i in orelse
            if isinstance(i, uni.CodeBlockStmt)
        ];
        if (len(val_orelse) != len(orelse)) {
            raise self.ice('Length mismatch in for orelse') ;
        }
        fin_orelse = uni.ElseStmt(body=val_orelse, kid=val_orelse) if orelse else None;
        if (isinstance(target, uni.Expr) and isinstance(iter, uni.Expr)) {
            return uni.InForStmt(
                target=target,
                is_async=True,
                collection=iter,
                body=valid_body,
                else_body=fin_orelse,
                kid=[target, iter, *valid_body, fin_orelse]
                if fin_orelse
                else [target, iter, *valid_body]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process While node.\n\n        class While(stmt):\n            __match_args__ = ("test", "body", "orelse")\n            test: expr\n            body: list[stmt]\n            orelse: list[stmt]\n        """
    def proc_while(self: PyastBuildPass, <>node: py_ast.While) -> uni.WhileStmt {
        <>test = self.convert(<>node.test);
        body = [self.convert(stmt) for stmt in <>node.body];
        valid_body = [
            stmt
            for stmt in body
            if isinstance(stmt, uni.CodeBlockStmt)
        ];
        if (len(valid_body) != len(body)) {
            raise self.ice('Length mismatch in while body') ;
        }
        orelse = [self.convert(i) for i in <>node.orelse];
        val_orelse = [
            i
            for i in orelse
            if isinstance(i, uni.CodeBlockStmt)
        ];
        if (len(val_orelse) != len(orelse)) {
            raise self.ice('Length mismatch in for orelse') ;
        }
        fin_orelse = uni.ElseStmt(body=val_orelse, kid=val_orelse) if orelse else None;
        if isinstance(<>test, uni.Expr) {
            return uni.WhileStmt(
                condition=<>test,
                body=valid_body,
                else_body=fin_orelse,
                kid=[<>test, *valid_body]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process If node.\n\n        class If(stmt):\n            __match_args__ = ("test", "body", "orelse")\n            test: expr\n            body: list[stmt]\n            orelse: list[stmt]\n        """
    def proc_if(self: PyastBuildPass, <>node: py_ast.If) -> uni.IfStmt {
        <>test = self.convert(<>node.test);
        body = [self.convert(stmt) for stmt in <>node.body];
        valid_body = [
            stmt
            for stmt in body
            if isinstance(stmt, uni.CodeBlockStmt)
        ];
        if (len(valid_body) != len(body)) {
            self.log_error('Length mismatch in async for body');
        }
        body2 = valid_body;
        orelse = [self.convert(stmt) for stmt in <>node.orelse];
        valid_orelse = [
            stmt
            for stmt in orelse
            if isinstance(stmt, uni.CodeBlockStmt)
        ];
        if valid_orelse {
            first_elm = valid_orelse[0];
            if (isinstance(first_elm, uni.IfStmt) and (len(valid_orelse) == 1)) {
                else_body: uni.ElseIf | uni.ElseStmt | None = uni.ElseIf(
                    condition=first_elm.condition,
                    body=first_elm.body,
                    else_body=first_elm.else_body,
                    kid=first_elm.kid
                );
            } else {
                else_body = uni.ElseStmt(body=valid_orelse, kid=valid_orelse);
            }
        } else {
            else_body = None;
        }
        if isinstance(<>test, uni.Expr) {
            ret = uni.IfStmt(
                condition=<>test,
                body=body2,
                else_body=else_body,
                kid=[<>test, *body2, else_body] if else_body else [<>test, *body2]
            );
        } else {
            raise self.ice() ;
        }
        return ret;
    }

    """Process With node.\n\n        class With(stmt):\n            __match_args__ = ("items", "body")\n            items: list[withitem]\n            body: list[stmt]\n        """
    def proc_with(self: PyastBuildPass, <>node: py_ast.With) -> uni.WithStmt {
        items = [self.convert(item) for item in <>node.items];
        valid_items = [
            item
            for item in items
            if isinstance(item, uni.ExprAsItem)
        ];
        if (len(valid_items) != len(items)) {
            raise self.ice('Length mismatch in with items') ;
        }
        body = [self.convert(stmt) for stmt in <>node.body];
        valid_body = [
            stmt
            for stmt in body
            if isinstance(stmt, uni.CodeBlockStmt)
        ];
        if (len(valid_body) != len(body)) {
            raise self.ice('Length mismatch in async for body') ;
        }
        return uni.WithStmt(
            is_async=False,
            exprs=valid_items,
            body=valid_body,
            kid=[*valid_items, *valid_body]
        );
    }

    """Process AsyncWith node.\n\n        class AsyncWith(stmt):\n            __match_args__ = ("items", "body")\n            items: list[withitem]\n            body: list[stmt]\n        """
    def proc_async_with(self: PyastBuildPass, <>node: py_ast.AsyncWith) -> uni.WithStmt {
        items = [self.convert(item) for item in <>node.items];
        valid_items = [
            item
            for item in items
            if isinstance(item, uni.ExprAsItem)
        ];
        if (len(valid_items) != len(items)) {
            raise self.ice('Length mismatch in with items') ;
        }
        body = [self.convert(stmt) for stmt in <>node.body];
        valid_body = [
            stmt
            for stmt in body
            if isinstance(stmt, uni.CodeBlockStmt)
        ];
        if (len(valid_body) != len(body)) {
            raise self.ice('Length mismatch in async for body') ;
        }
        return uni.WithStmt(
            is_async=True,
            exprs=valid_items,
            body=valid_body,
            kid=[*valid_items, *valid_body]
        );
    }

    """Process python node.\n\n        class Raise(stmt):\n            exc: expr | None\n            cause: expr | None\n        """
    def proc_raise(self: PyastBuildPass, <>node: py_ast.Raise) -> uni.RaiseStmt {
        exc = self.convert(<>node.exc) if <>node.exc else None;
        cause = self.convert(<>node.cause) if <>node.cause else None;
        kid: list[(uni.Expr | uni.Token)] = [];
        if isinstance(exc, uni.Expr) {
            kid = [exc];
        }
        if isinstance(cause, uni.Expr) {
            kid.append(cause);
        }
        if not (exc and cause) {
            kid.append(self.operator(Tok.KW_RAISE, 'raise'));
        }
        if (
            (isinstance(cause, uni.Expr) or (cause is None))
            and (isinstance(exc, uni.Expr) or (exc is None))
        ) {
            if (exc and not <>node.cause) {
                return uni.RaiseStmt(
                    cause=exc,
                    from_target=None,
                    kid=[self.operator(Tok.KW_RAISE, 'raise'), exc]
                );
            } else {
                return uni.RaiseStmt(cause=cause, from_target=exc, kid=kid);
            }
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Assert(stmt):\n            test: expr\n            msg: expr | None\n        """
    def proc_assert(self: PyastBuildPass, <>node: py_ast.Assert) -> uni.AssertStmt {
        <>test = self.convert(<>node.test);
        msg = self.convert(<>node.msg) if <>node.msg else None;
        if (
            isinstance(<>test, uni.Expr)
            and (isinstance(msg, uni.Expr) or (msg is None))
        ) {
            return uni.AssertStmt(
                condition=<>test, error_msg=msg, kid=[<>test, msg] if msg else [<>test]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Proassignment targetscess python node.\n\n        class Attribute(expr):\n        if sys.version_info >= (3, 10):\n            __match_args__ = ("value", "attr", "ctx")\n        value: expr\n        attr: _Identifier\n        ctx: expr_context\n        """
    def proc_attribute(
        self: PyastBuildPass, <>node: py_ast.Attribute
    ) -> uni.AtomTrailer {
        value = self.convert(<>node.value);
        if (
            isinstance(value, uni.FuncCall)
            and isinstance(value.target, uni.Name)
            and (value.target.value == 'super')
        ) {
            tok = uni.Name(
                orig_src=self.orig_src,
                name=Tok.KW_SUPER,
                value='super',
                line=<>node.lineno,
                end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                col_start=<>node.col_offset,
                col_end=(<>node.col_offset + len('super')),
                pos_start=0,
                pos_end=0
            );
            value = uni.SpecialVarRef(var=tok);
        }
        attribute = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value='init' if (<>node.attr == '__init__') else <>node.attr,
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(<>node.attr)),
            pos_start=0,
            pos_end=0,
            is_kwesc=(<>node.attr == 'init')
        );
        if isinstance(value, uni.Expr) {
            return uni.AtomTrailer(
                target=value,
                right=attribute,
                is_attr=True,
                is_null_ok=False,
                kid=[value, attribute]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Await(expr):\n            value: expr\n        """
    def proc_await(self: PyastBuildPass, <>node: py_ast.Await) -> uni.AwaitExpr {
        value = self.convert(<>node.value);
        if isinstance(value, uni.Expr) {
            return uni.AwaitExpr(target=value, kid=[value]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class BinOp(expr):\n            if sys.version_info >= (3, 10):\n                __match_args__ = ("left", "op", "right")\n            left: expr\n            op: operator\n            right: expr\n        """
    def proc_bin_op(
        self: PyastBuildPass, <>node: py_ast.BinOp
    ) -> (uni.AtomUnit | uni.BinaryExpr) {
        left = self.convert(<>node.left);
        op = self.convert(<>node.op);
        right = self.convert(<>node.right);
        if (
            isinstance(left, uni.Expr)
            and isinstance(op, uni.Token)
            and isinstance(right, uni.Expr)
        ) {
            unwrapped_left = left;
            is_same_op_chain = False;
            if (
                isinstance(left, uni.AtomUnit)
                and isinstance(left.value, uni.BinaryExpr)
                and isinstance(left.value.op, uni.Token)
                and (left.value.op.value == op.value)
            ) {
                unwrapped_left = left.value;
                is_same_op_chain = True;
            }
            value = uni.BinaryExpr(
                left=unwrapped_left,
                op=op,
                right=right,
                kid=[unwrapped_left, op, right]
            );
            if is_same_op_chain {
                return value;
            }
            return uni.AtomUnit(
                value=value,
                kid=[
                    self.operator(Tok.RPAREN, '('),
                    value,
                    self.operator(Tok.LPAREN, ')')
                ]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class UnaryOp(expr):\n            op: unaryop\n            operand: expr\n        """
    def proc_unary_op(self: PyastBuildPass, <>node: py_ast.UnaryOp) -> uni.UnaryExpr {
        op = self.convert(<>node.op);
        operand = self.convert(<>node.operand);
        if (isinstance(op, uni.Token) and isinstance(operand, uni.Expr)) {
            return uni.UnaryExpr(op=op, operand=operand, kid=[op, operand]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class BoolOp(expr): a and b and c\n            op: boolop\n            values: list[expr]\n        """
    def proc_bool_op(self: PyastBuildPass, <>node: py_ast.BoolOp) -> uni.AtomUnit {
        op = self.convert(<>node.op);
        values = [self.convert(value) for value in <>node.values];
        valid = [
            value
            for value in values
            if isinstance(value, uni.Expr)
        ];
        if (isinstance(op, uni.Token) and (len(valid) == len(values))) {
            expr = uni.BoolExpr(op=op, values=valid, kid=[op, *valid]);
            return uni.AtomUnit(
                value=expr,
                kid=[
                    self.operator(Tok.RPAREN, '('),
                    expr,
                    self.operator(Tok.LPAREN, ')')
                ]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node."""
    def proc_break(self: PyastBuildPass, <>node: py_ast.Break) -> uni.CtrlStmt {
        break_tok = uni.Token(
            orig_src=self.orig_src,
            name=Tok.KW_BREAK,
            value='break',
            line=0,
            end_line=0,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0
        );
        return uni.CtrlStmt(ctrl=break_tok, kid=[break_tok]);
    }

    """Process python node.\n\n        class Call(expr):\n        if sys.version_info >= (3, 10):\n            __match_args__ = ("func", "args", "keywords")\n        func: expr\n        args: list[expr]\n        keywords: list[keyword]\n        """
    def proc_call(self: PyastBuildPass, <>node: py_ast.Call) -> uni.FuncCall {
        func = self.convert(<>node.func);
        params_in: list[(uni.Expr | uni.KWPair)] = [];
        args = [self.convert(arg) for arg in <>node.args];
        keywords = [self.convert(keyword) for keyword in <>node.keywords];
        for i in args {
            if isinstance(i, uni.Expr) {
                params_in.append(i);
            }
        }
        for i in keywords {
            if isinstance(i, uni.KWPair) {
                params_in.append(i);
            }
        }
        kids = [func, *params_in] if (len(params_in) != 0) else [func];
        if isinstance(func, uni.Expr) {
            return uni.FuncCall(
                target=func, params=params_in, genai_call=None, kid=kids
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Compare(expr):\n        if sys.version_info >= (3, 10):\n            __match_args__ = ("left", "ops", "comparators")\n        left: expr\n        ops: list[cmpop]\n        comparators: list[expr]\n        """
    def proc_compare(self: PyastBuildPass, <>node: py_ast.Compare) -> uni.AtomUnit {
        left = self.convert(<>node.left);
        comparators = [self.convert(comparator) for comparator in <>node.comparators];
        valid_comparators = [
            comparator
            for comparator in comparators
            if isinstance(comparator, uni.Expr)
        ];
        ops = [self.convert(op) for op in <>node.ops];
        valid_ops = [
            op
            for op in ops
            if isinstance(op, uni.Token)
        ];
        kids = [left, *valid_ops, *valid_comparators];
        if (
            isinstance(left, uni.Expr)
            and (len(ops) == len(valid_ops))
            and (len(comparators) == len(valid_comparators))
        ) {
            expr = uni.CompareExpr(
                left=left, rights=valid_comparators, ops=valid_ops, kid=kids
            );
            return uni.AtomUnit(
                value=expr,
                kid=[
                    self.operator(Tok.RPAREN, '('),
                    expr,
                    self.operator(Tok.LPAREN, ')')
                ]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Constant(expr):\n            value: Any  # None, str, bytes, bool, int, float, complex, Ellipsis\n            kind: str | None\n            # Aliases for value, for backwards compatibility\n            s: Any\n            n: int | float | complex\n        """
    def proc_constant(self: PyastBuildPass, <>node: py_ast.Constant) -> uni.Literal {
        type_mapping = {
            int: uni.Int,
            float: uni.Float,
            str: uni.String,
            <>bytes: uni.String,
            bool: uni.Bool,
            <>type(None): uni.Null
        };
        value_type = <>type(<>node.value);
        if (value_type in type_mapping) {
            if (value_type is None) {
                token_type = 'NULL';
            } elif (value_type is str) {
                token_type = 'STRING';
            } else {
                token_type = f"{value_type.__name__.upper()}";
            }
            if (value_type is str) {
                raw_repr = repr(<>node.value);
                quote = "'" if raw_repr.startswith("'") else '"';
                value = f"{quote}{raw_repr[1:-1]}{quote}";
            } else {
                value = str(<>node.value);
            }
            return type_mapping[value_type](
                orig_src=self.orig_src,
                name=token_type,
                value=value,
                line=<>node.lineno,
                end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                col_start=<>node.col_offset,
                col_end=(<>node.col_offset + len(str(<>node.value))),
                pos_start=0,
                pos_end=0
            );
        } elif (<>node.value == Ellipsis) {
            return uni.Ellipsis(
                orig_src=self.orig_src,
                name=Tok.ELLIPSIS,
                value='...',
                line=<>node.lineno,
                end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                col_start=<>node.col_offset,
                col_end=(<>node.col_offset + 3),
                pos_start=0,
                pos_end=0
            );
        } else {
            raise self.ice('Invalid type for constant') ;
        }
    }

    """Process python node."""
    def proc_continue(self: PyastBuildPass, <>node: py_ast.Continue) -> uni.CtrlStmt {
        continue_tok = uni.Token(
            orig_src=self.orig_src,
            name=Tok.KW_CONTINUE,
            value='continue',
            line=0,
            end_line=0,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0
        );
        return uni.CtrlStmt(ctrl=continue_tok, kid=[continue_tok]);
    }

    """Process python node.\n\n        class Dict(expr):\n            keys: list[expr | None]\n            values: list[expr]\n        """
    def proc_dict(self: PyastBuildPass, <>node: py_ast.Dict) -> uni.DictVal {
        keys = [self.convert(i) if i else None for i in <>node.keys];
        values = [self.convert(i) for i in <>node.values];
        valid_keys = [
            i
            for i in keys
            if (isinstance(i, uni.Expr) or (i is None))
        ];
        valid_values = [
            i
            for i in values
            if isinstance(i, uni.Expr)
        ];
        kvpair: list[uni.KVPair] = [];
        for i in range(len(values)) {
            key_pluck = valid_keys[i];
            kvp = uni.KVPair(
                key=key_pluck,
                value=valid_values[i],
                kid=[key_pluck, valid_values[i]] if key_pluck else [valid_values[i]]
            );
            kvpair.append(kvp);
        }
        return uni.DictVal(
            kv_pairs=kvpair,
            kid=[*kvpair]
            if len(kvpair)
            else [self.operator(Tok.LBRACE, '{'), self.operator(Tok.RBRACE, '}')]
        );
    }

    """Process python node.\n\n        class DictComp(expr):\n            key: expr\n            value: expr\n            generators: list[comprehension]\n        """
    def proc_dict_comp(self: PyastBuildPass, <>node: py_ast.DictComp) -> uni.DictCompr {
        key = self.convert(<>node.key);
        value = self.convert(<>node.value);
        if (isinstance(key, uni.Expr) and isinstance(value, uni.Expr)) {
            kv_pair = uni.KVPair(key=key, value=value, kid=[key, value]);
        } else {
            raise self.ice() ;
        }
        generators = [self.convert(i) for i in <>node.generators];
        valid = [
            i
            for i in generators
            if isinstance(i, uni.InnerCompr)
        ];
        if (len(valid) != len(generators)) {
            raise self.ice('Length mismatch in dict compr generators') ;
        }
        return uni.DictCompr(kv_pair=kv_pair, compr=valid, kid=[kv_pair, *valid]);
    }

    """Process python node."""
    def proc_ellipsis(self: PyastBuildPass, <>node: py_ast.Constant) -> None { }

    """Process python node.\n\n        class ExceptHandler(excepthandler):\n            type: expr | None\n            name: _Identifier | None\n            body: list[stmt]\n        """
    def proc_except_handler(
        self: PyastBuildPass, <>node: py_ast.ExceptHandler
    ) -> uni.Except {
        <>type = self.convert(<>node.type) if <>node.type else None;
        name: (uni.Name | None) = None;
        if (not <>type and not <>node.name) {
            <>type = uni.Name(
                orig_src=self.orig_src,
                name=Tok.NAME,
                value='Exception',
                line=<>node.lineno,
                end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                col_start=<>node.col_offset,
                col_end=(<>node.col_offset + 9),
                pos_start=0,
                pos_end=0
            );
            name = uni.Name(
                orig_src=self.orig_src,
                name=Tok.NAME,
                value='e',
                line=<>node.lineno,
                end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                col_start=<>node.col_offset,
                col_end=(<>node.col_offset + 1),
                pos_start=0,
                pos_end=0
            );
        } else {
            name = uni.Name(
                orig_src=self.orig_src,
                name=Tok.NAME,
                value=<>node.name,
                line=<>node.lineno,
                end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                col_start=<>node.col_offset,
                col_end=(<>node.col_offset + len(<>node.name)),
                pos_start=0,
                pos_end=0
            )
            if <>node.name
            else None;
        }
        body = [self.convert(i) for i in <>node.body];
        valid = [
            i
            for i in body
            if isinstance(i, uni.CodeBlockStmt)
        ];
        if (len(valid) != len(body)) {
            raise self.ice('Length mismatch in except handler body') ;
        }
        kid = [
            item
            for item in [<>type, name, *valid]
            if item
        ];
        if (isinstance(<>type, uni.Expr) and (isinstance(name, uni.Name) or not name)) {
            return uni.Except(ex_type=<>type, name=name, body=valid, kid=kid);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Expr(stmt):\n            value: expr\n        """
    def proc_expr(self: PyastBuildPass, <>node: py_ast.Expr) -> uni.ExprStmt {
        value = self.convert(<>node.value);
        if isinstance(value, uni.Expr) {
            return uni.ExprStmt(expr=value, in_fstring=False, kid=[value]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class FormattedValue(expr):\n        if sys.version_info >= (3, 10):\n            __match_args__ = ("value", "conversion", "format_spec")\n        value: expr\n        conversion: int\n        format_spec: expr | None\n        """
    def proc_formatted_value(
        self: PyastBuildPass, <>node: py_ast.FormattedValue
    ) -> uni.FormattedValue {
        prev_in_fstring = self.in_fstring_expr;
        self.in_fstring_expr = True;
        value = self.convert(<>node.value);
        fmt_spec = cast(uni.Expr, self.convert(<>node.format_spec))
        if <>node.format_spec
        else None;
        self.in_fstring_expr = prev_in_fstring;
        if isinstance(value, uni.Expr) {
            ret = uni.FormattedValue(
                format_part=value,
                conversion=<>node.conversion,
                format_spec=fmt_spec,
                kid=[value]
            );
        } else {
            raise self.ice() ;
        }
        return ret;
    }

    """Process python node."""
    def proc_function_type(self: PyastBuildPass, <>node: py_ast.FunctionType) -> None { }

    """Process python node..\n\n        class SetComp(expr):\n            elt: expr\n            generators: list[comprehension]\n        """
    def proc_generator_exp(
        self: PyastBuildPass, <>node: py_ast.GeneratorExp
    ) -> uni.GenCompr {
        elt = self.convert(<>node.elt);
        generators = [self.convert(gen) for gen in <>node.generators];
        valid = [
            gen
            for gen in generators
            if isinstance(gen, uni.InnerCompr)
        ];
        if (len(generators) != len(valid)) {
            raise self.ice('Length mismatch in list comp generators') ;
        }
        if isinstance(elt, uni.Expr) {
            return uni.GenCompr(out_expr=elt, compr=valid, kid=[elt, *valid]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Global(stmt):\n            names: list[_Identifier]\n        """
    def proc_global(self: PyastBuildPass, <>node: py_ast.Global) -> uni.GlobalStmt {
        names: list[uni.NameAtom] = [];
        for id in <>node.names {
            names.append(
                uni.Name(
                    orig_src=self.orig_src,
                    name=Tok.NAME,
                    value=id,
                    line=<>node.lineno,
                    end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                    col_start=<>node.col_offset,
                    col_end=(<>node.col_offset + len(id)),
                    pos_start=0,
                    pos_end=0
                )
            );
        }
        return uni.GlobalStmt(target=names, kid=names);
    }

    """Process python node.\n\n        class IfExp(expr):\n            test: expr\n            body: expr\n            orelse: expr\n        """
    def proc_if_exp(self: PyastBuildPass, <>node: py_ast.IfExp) -> uni.IfElseExpr {
        <>test = self.convert(<>node.test);
        body = self.convert(<>node.body);
        orelse = self.convert(<>node.orelse);
        if (
            isinstance(<>test, uni.Expr)
            and isinstance(body, uni.Expr)
            and isinstance(orelse, uni.Expr)
        ) {
            return uni.IfElseExpr(
                value=body,
                condition=<>test,
                else_value=orelse,
                kid=[body, <>test, orelse]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Import(stmt):\n            names: list[alias]\n        """
    def proc_import(self: PyastBuildPass, <>node: py_ast.Import) -> uni.Import {
        names = [self.convert(name) for name in <>node.names];
        valid_names = [
            name
            for name in names
            if isinstance(name, uni.ExprAsItem)
        ];
        if (len(valid_names) != len(names)) {
            self.log_error('Length mismatch in import names');
        }
        paths = [];
        for name in valid_names {
            if (
                isinstance(name.expr, uni.Name)
                and (isinstance(name.alias, uni.Name) or (name.alias is None))
            ) {
                paths.append(
                    uni.ModulePath(
                        path=[name.expr],
                        level=0,
                        alias=name.alias,
                        kid=[
                            i
                            for i in name.kid
                            if i
                        ]
                    )
                );
            } else {
                raise self.ice() ;
            }
        }
        ret = uni.Import(from_loc=None, items=paths, is_absorb=False, kid=paths);
        return ret;
    }

    """Process python node.\n\n        class ImportFrom(stmt):\n            module: str | None\n            names: list[alias]\n            level: int\n        """
    def proc_import_from(self: PyastBuildPass, <>node: py_ast.ImportFrom) -> uni.Import {
        lang = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value='py',
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=0,
            pos_start=0,
            pos_end=0
        );
        modpaths: list[uni.Name] = [];
        if <>node.module {
            for i in <>node.module.split('.') {
                modpaths.append(
                    uni.Name(
                        orig_src=self.orig_src,
                        name=Tok.NAME,
                        value=i,
                        line=<>node.lineno,
                        end_line=<>node.end_lineno
                        if <>node.end_lineno
                        else <>node.lineno,
                        col_start=0,
                        col_end=0,
                        pos_start=0,
                        pos_end=0
                    )
                );
            }
        }
        moddots = [self.operator(Tok.DOT, '.') for _ in range(<>node.level)];
        modparts = moddots + modpaths;
        path = uni.ModulePath(
            path=modpaths if modpaths else None,
            level=<>node.level,
            alias=None,
            kid=modparts
        );
        names = [self.convert(name) for name in <>node.names];
        valid_names = [];
        for name in names {
            if (
                isinstance(name, uni.ExprAsItem)
                and isinstance(name.expr, uni.Name)
                and (isinstance(name.alias, uni.Name) or (name.alias is None))
            ) {
                valid_names.append(
                    uni.ModuleItem(
                        name=name.expr,
                        alias=name.alias if name.alias else None,
                        kid=[
                            i
                            for i in name.kid
                            if i
                        ]
                    )
                );
            } else {
                raise self.ice() ;
            }
        }
        items = valid_names;
        if not items {
            raise self.ice('No valid names in import from') ;
        }
        pytag = uni.SubTag[uni.Name](tag=lang, kid=[lang]);
        if ((len(<>node.names) == 1) and (<>node.names[0].name == '*')) {
            ret = uni.Import(
                from_loc=None, items=[path], is_absorb=True, kid=[pytag, path]
            );
            return ret;
        }
        ret = uni.Import(
            from_loc=path, items=items, is_absorb=False, kid=[pytag, path, *items]
        );
        return ret;
    }

    """Process python node.\n\n        class JoinedStr(expr):\n        if sys.version_info >= (3, 10):\n            __match_args__ = ("values",)\n        values: list[expr]\n        """
    def proc_joined_str(
        self: PyastBuildPass, <>node: py_ast.JoinedStr
    ) -> uni.MultiString {
        valid: list[(uni.String | uni.FormattedValue)] = [];
        for i in <>node.values {
            if (isinstance(i, py_ast.Constant) and isinstance(i.value, str)) {
                valid.append(
                    uni.String(
                        orig_src=self.orig_src,
                        name='STRING',
                        value=i.value,
                        line=i.lineno,
                        end_line=i.end_lineno if i.end_lineno else i.lineno,
                        col_start=i.col_offset,
                        col_end=(i.col_offset + len(i.value)),
                        pos_start=0,
                        pos_end=0
                    )
                );
            } elif isinstance(i, py_ast.FormattedValue) {
                converted = self.convert(i);
                if isinstance(converted, uni.FormattedValue) {
                    valid.append(converted);
                }
            } else {
                raise self.ice('Invalid node in joined str') ;
            }
        }
        ast_seg = py_ast.get_source_segment(self.orig_src.code, <>node);
        if (ast_seg is None) {
            ast_seg = 'f""';
        }
        <>match = re.match('(?i)(fr|rf|f)(\'{3}|\\"{3}|\'|\\")', ast_seg);
        if <>match {
            (prefix, quote) = <>match.groups();
            start = <>match.group(0);
            end = quote;
        } else {
            start = "f'";
            end = "'";
        }
        all_content = ''.join(
            part.lit_value
            for part in valid
            if isinstance(part, uni.String)
        );
        has_single = "'" in all_content;
        has_double = '"' in all_content;
        is_triple = len(end) == 3;
        if (has_single and has_double and not is_triple) {
            if ("'" in end) {
                start = 'f"""';
                end = '"""';
            } else {
                start = "f'''";
                end = "'''";
            }
        } elif ((("'" in end) and has_single) or (('"' in end) and has_double)) {
            if ("'" in end) {
                start = start.replace("'", '"');
                end = end.replace("'", '"');
            } else {
                start = start.replace('"', "'");
                end = end.replace('"', "'");
            }
        }
        tok_start = self.operator(Tok.STRING, start);
        tok_end = self.operator(Tok.STRING, end);
        fstr = uni.FString(
            start=tok_start,
            parts=valid,
            end=tok_end,
            kid=[tok_start, *valid, tok_end] if valid else [uni.EmptyToken()]
        );
        return uni.MultiString(strings=[fstr], kid=[fstr]);
    }

    """Process python node.\n\n        class Lambda(expr):\n            args: arguments\n            body: expr\n        """
    def proc_lambda(self: PyastBuildPass, <>node: py_ast.Lambda) -> uni.LambdaExpr {
        args = self.convert(<>node.args);
        body = self.convert(<>node.body);
        if (isinstance(args, uni.FuncSignature) and isinstance(body, uni.Expr)) {
            return uni.LambdaExpr(signature=args, body=body, kid=[args, body]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class List(expr):\n            elts: list[expr]\n            ctx: expr_context\n        """
    def proc_list(self: PyastBuildPass, <>node: py_ast.List) -> uni.ListVal {
        elts = [self.convert(elt) for elt in <>node.elts];
        valid_elts = [
            elt
            for elt in elts
            if isinstance(elt, uni.Expr)
        ];
        if (len(valid_elts) != len(elts)) {
            raise self.ice('Length mismatch in list elements') ;
        }
        l_square = self.operator(Tok.LSQUARE, '[');
        r_square = self.operator(Tok.RSQUARE, ']');
        return uni.ListVal(
            values=valid_elts,
            kid=[*valid_elts] if valid_elts else [l_square, r_square]
        );
    }

    """Process python node.\n\n        class ListComp(expr):\n            elt: expr\n            generators: list[comprehension]\n        """
    def proc_list_comp(self: PyastBuildPass, <>node: py_ast.ListComp) -> uni.ListCompr {
        elt = self.convert(<>node.elt);
        generators = [self.convert(gen) for gen in <>node.generators];
        valid = [
            gen
            for gen in generators
            if isinstance(gen, uni.InnerCompr)
        ];
        if (len(generators) != len(valid)) {
            raise self.ice('Length mismatch in list comp generators') ;
        }
        if isinstance(elt, uni.Expr) {
            return uni.ListCompr(out_expr=elt, compr=valid, kid=[elt, *valid]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Match(stmt):\n            subject: expr\n            cases: list[match_case]\n        """
    def proc_match(self: PyastBuildPass, <>node: py_ast.Match) -> uni.MatchStmt {
        subject = self.convert(<>node.subject);
        cases = [self.convert(i) for i in <>node.cases];
        valid = [
            <>case
            for <>case in cases
            if isinstance(<>case, uni.MatchCase)
        ];
        if isinstance(subject, uni.Expr) {
            return uni.MatchStmt(target=subject, cases=valid, kid=[subject, *valid]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class MatchAs(pattern):\n            pattern: _Pattern | None\n            name: _Identifier | None\n        """
    def proc_match_as(
        self: PyastBuildPass, <>node: py_ast.MatchAs
    ) -> (uni.MatchAs | uni.MatchWild) {
        pattern = self.convert(<>node.pattern) if <>node.pattern else None;
        name = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value=<>node.name if <>node.name else '_',
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(<>node.name))
            if <>node.name
            else (<>node.col_offset + 1),
            pos_start=0,
            pos_end=0
        );
        if (
            (name.value == '_')
            or ((pattern is not None) and not isinstance(pattern, uni.MatchPattern))
        ) {
            return uni.MatchWild(kid=[name]);
        }
        return uni.MatchAs(
            name=name,
            pattern=pattern,
            kid=[name] if (pattern is None) else [name, pattern]
        );
    }

    """Process python node.\n\n        class MatchClass(pattern):\n            cls: expr\n            patterns: list[pattern]\n            kwd_attrs: list[_Identifier]\n            kwd_patterns: list[pattern]\n        """
    def proc_match_class(
        self: PyastBuildPass, <>node: py_ast.MatchClass
    ) -> uni.MatchArch {
        self.in_match_pattern = True;
        cls = self.convert(<>node.cls);
        self.in_match_pattern = False;
        kid = [cls];
        if (len(<>node.patterns) != 0) {
            patterns = [self.convert(i) for i in <>node.patterns];
            valid_patterns = [
                i
                for i in patterns
                if isinstance(i, uni.MatchPattern)
            ];
            if (len(patterns) == len(valid_patterns)) {
                kid.extend(valid_patterns);
                patterns_list = valid_patterns;
            } else {
                raise self.ice() ;
            }
        } else {
            patterns_list = None;
        }
        if len(<>node.kwd_patterns) {
            names: list[uni.Name] = [];
            kv_pairs: list[uni.MatchKVPair] = [];
            for kwd_attrs in <>node.kwd_attrs {
                names.append(
                    uni.Name(
                        orig_src=self.orig_src,
                        name=Tok.NAME,
                        value=kwd_attrs,
                        line=<>node.lineno,
                        end_line=<>node.end_lineno
                        if <>node.end_lineno
                        else <>node.lineno,
                        col_start=<>node.col_offset,
                        col_end=(<>node.col_offset + len(kwd_attrs)),
                        pos_start=0,
                        pos_end=0
                    )
                );
            }
            kwd_patterns = [self.convert(i) for i in <>node.kwd_patterns];
            valid_kwd_patterns = [
                i
                for i in kwd_patterns
                if isinstance(i, uni.MatchPattern)
            ];
            for i in range(len(kwd_patterns)) {
                kv_pairs.append(
                    uni.MatchKVPair(
                        key=names[i],
                        value=valid_kwd_patterns[i],
                        kid=[names[i], valid_kwd_patterns[i]]
                    )
                );
            }
            kid.extend(kv_pairs);
            kw_patterns_list = kv_pairs;
        } else {
            kw_patterns_list = None;
        }
        if isinstance(cls, (uni.NameAtom, uni.AtomTrailer)) {
            return uni.MatchArch(
                name=cls,
                arg_patterns=patterns_list,
                kw_patterns=kw_patterns_list,
                kid=kid
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class MatchMapping(pattern):\n            keys: list[expr]\n            patterns: list[pattern]\n            rest: _Identifier | None\n        """
    def proc_match_mapping(
        self: PyastBuildPass, <>node: py_ast.MatchMapping
    ) -> uni.MatchMapping {
        values: list[(uni.MatchKVPair | uni.MatchStar)] = [];
        keys = [self.convert(i) for i in <>node.keys];
        valid_keys = [
            i
            for i in keys
            if isinstance(i, (uni.MatchPattern, uni.NameAtom, uni.AtomExpr))
        ];
        patterns = [self.convert(i) for i in <>node.patterns];
        valid_patterns = [
            i
            for i in patterns
            if isinstance(i, uni.MatchPattern)
        ];
        for i in range(len(valid_keys)) {
            kv_pair = uni.MatchKVPair(
                key=valid_keys[i],
                value=valid_patterns[i],
                kid=[valid_keys[i], valid_patterns[i]]
            );
            values.append(kv_pair);
        }
        if <>node.rest {
            name = uni.Name(
                orig_src=self.orig_src,
                name=Tok.NAME,
                value=<>node.rest,
                line=<>node.lineno,
                end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                col_start=<>node.col_offset,
                col_end=(<>node.col_offset + len(<>node.rest)),
                pos_start=0,
                pos_end=0
            );
            values.append(uni.MatchStar(name=name, is_list=False, kid=[name]));
        }
        return uni.MatchMapping(values=values, kid=values);
    }

    """Process python node.\n\n        class MatchOr(pattern):\n            patterns: list[pattern]\n        """
    def proc_match_or(self: PyastBuildPass, <>node: py_ast.MatchOr) -> uni.MatchOr {
        patterns = [self.convert(i) for i in <>node.patterns];
        valid = [
            i
            for i in patterns
            if isinstance(i, uni.MatchPattern)
        ];
        return uni.MatchOr(patterns=valid, kid=valid);
    }

    """Process python node.\n\n        class MatchSequence(pattern):\n            patterns: list[pattern]\n        """
    def proc_match_sequence(
        self: PyastBuildPass, <>node: py_ast.MatchSequence
    ) -> uni.MatchSequence {
        patterns = [self.convert(i) for i in <>node.patterns];
        valid = [
            i
            for i in patterns
            if isinstance(i, uni.MatchPattern)
        ];
        if (len(patterns) == len(valid)) {
            return uni.MatchSequence(values=valid, kid=valid);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class MatchSingleton(pattern):\n            value: Literal[True, False] | None\n        """
    def proc_match_singleton(
        self: PyastBuildPass, <>node: py_ast.MatchSingleton
    ) -> uni.MatchSingleton {
        <>type = Tok.NULL if (<>node.value is None) else Tok.BOOL;
        ret_type = uni.Null if (<>node.value is None) else uni.Bool;
        value = ret_type(
            orig_src=self.orig_src,
            name=<>type,
            value=str(<>node.value),
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(str(<>node.value))),
            pos_start=0,
            pos_end=0
        );
        if isinstance(value, (uni.Bool, uni.Null)) {
            return uni.MatchSingleton(value=value, kid=[value]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class MatchStar(pattern):\n            name: _Identifier | None\n        """
    def proc_match_star(
        self: PyastBuildPass, <>node: py_ast.MatchStar
    ) -> uni.MatchStar {
        name = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value=<>node.name if <>node.name else '_',
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(<>node.name if <>node.name else '_')),
            pos_start=0,
            pos_end=0
        );
        return uni.MatchStar(name=name, is_list=True, kid=[name]);
    }

    """Process python node.\n\n        class MatchValue(pattern):\n            value: expr\n        """
    def proc_match_value(
        self: PyastBuildPass, <>node: py_ast.MatchValue
    ) -> uni.MatchValue {
        value = self.convert(<>node.value);
        if isinstance(value, uni.Expr) {
            return uni.MatchValue(value=value, kid=[value]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Name(expr):\n        if sys.version_info >= (3, 10):\n            __match_args__ = ("id", "ctx")\n        id: _Identifier\n        ctx: expr_context\n        """
    def proc_name(self: PyastBuildPass, <>node: py_ast.Name) -> uni.Name {
        import from jaclang.pycore.jac_parser { TOKEN_MAP }
        reserved_keywords = [
            v
            for (_, v) in TOKEN_MAP.items()
            if (v not in ['float', 'int', 'str', 'bool', 'self'])
        ];
        should_escape = (
            (<>node.id in reserved_keywords)
            and not self.in_type_annotation
            and not self.in_match_pattern
            and not self.in_fstring_expr
        );
        ret = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value=<>node.id,
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(<>node.id)),
            pos_start=0,
            pos_end=0,
            is_kwesc=should_escape
        );
        return ret;
    }

    """Process python node.\n\n        class NamedExpr(expr):\n            target: Name\n            value: expr\n        """
    def proc_named_expr(self: PyastBuildPass, <>node: py_ast.NamedExpr) -> uni.AtomUnit {
        target = self.convert(<>node.target);
        value = self.convert(<>node.value);
        if (isinstance(value, uni.Expr) and isinstance(target, uni.Name)) {
            op = self.operator(Tok.WALRUS_EQ, ':=');
            if isinstance(value, uni.IfElseExpr) {
                value = uni.AtomUnit(
                    value=value,
                    kid=[
                        self.operator(Tok.LPAREN, '('),
                        value,
                        self.operator(Tok.RPAREN, ')')
                    ]
                );
            }
            expr = uni.BinaryExpr(
                left=target, op=op, right=value, kid=[target, op, value]
            );
            return uni.AtomUnit(
                value=expr,
                kid=[
                    self.operator(Tok.LPAREN, '('),
                    expr,
                    self.operator(Tok.RPAREN, ')')
                ]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Nonlocal(stmt):\n            names: list[_Identifier]\n        """
    def proc_nonlocal(
        self: PyastBuildPass, <>node: py_ast.Nonlocal
    ) -> uni.NonLocalStmt {
        import from jaclang.pycore.jac_parser { TOKEN_MAP }
        reserved_keywords = [v for (_, v) in TOKEN_MAP.items()];
        names: list[uni.NameAtom] = [];
        for name in <>node.names {
            names.append(
                uni.Name(
                    orig_src=self.orig_src,
                    name=Tok.NAME,
                    value=name,
                    line=<>node.lineno,
                    end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                    col_start=<>node.col_offset,
                    col_end=(<>node.col_offset + len(name)),
                    pos_start=0,
                    pos_end=0,
                    is_kwesc=(name in reserved_keywords)
                )
            );
        }
        return uni.NonLocalStmt(target=names, kid=names);
    }

    """Process python node."""
    def proc_pass(self: PyastBuildPass, <>node: py_ast.Pass) -> uni.Semi {
        return uni.Semi(
            orig_src=self.orig_src,
            name=Tok.SEMI,
            value=';',
            line=0,
            end_line=0,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0
        );
    }

    """Process python node.\n\n        class Set(expr):\n            elts: list[expr]\n        """
    def proc_set(self: PyastBuildPass, <>node: py_ast.Set) -> uni.SetVal {
        if (len(<>node.elts) != 0) {
            elts = [self.convert(i) for i in <>node.elts];
            valid = [
                i
                for i in elts
                if isinstance(i, uni.Expr)
            ];
            if (len(valid) != len(elts)) {
                raise self.ice('Length mismatch in set body') ;
            }
            kid: list[uni.UniNode] = [*valid];
        } else {
            valid = [];
            l_brace = self.operator(Tok.LBRACE, '{');
            r_brace = self.operator(Tok.RBRACE, '}');
            kid = [l_brace, r_brace];
        }
        return uni.SetVal(values=valid, kid=kid);
    }

    """Process python node.\n\n        class SetComp(expr):\n            elt: expr\n            generators: list[comprehension]\n        """
    def proc_set_comp(self: PyastBuildPass, <>node: py_ast.SetComp) -> uni.ListCompr {
        elt = self.convert(<>node.elt);
        generators = [self.convert(gen) for gen in <>node.generators];
        valid = [
            gen
            for gen in generators
            if isinstance(gen, uni.InnerCompr)
        ];
        if (len(generators) != len(valid)) {
            raise self.ice('Length mismatch in list comp generators') ;
        }
        if isinstance(elt, uni.Expr) {
            return uni.SetCompr(out_expr=elt, compr=valid, kid=[elt, *valid]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Slice(_Slice):\n            lower: expr | None\n            upper: expr | None\n            step: expr | None\n        """
    def proc_slice(self: PyastBuildPass, <>node: py_ast.Slice) -> uni.IndexSlice {
        lower = self.convert(<>node.lower) if <>node.lower else None;
        upper = self.convert(<>node.upper) if <>node.upper else None;
        step = self.convert(<>node.step) if <>node.step else None;
        valid_kid = [
            i
            for i in [lower, upper, step]
            if i
        ];
        if not valid_kid {
            valid_kid = [self.operator(Tok.COLON, ':')];
        }
        if (
            (isinstance(lower, uni.Expr) or (lower is None))
            and (isinstance(upper, uni.Expr) or (upper is None))
            and (isinstance(step, uni.Expr) or (step is None))
        ) {
            return uni.IndexSlice(
                slices=[uni.IndexSlice.Slice(lower, upper, step)],
                is_range=True,
                kid=valid_kid
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Starred(expr):\n            value: expr\n            ctx: expr_context\n        """
    def proc_starred(self: PyastBuildPass, <>node: py_ast.Starred) -> uni.UnaryExpr {
        star_tok = self.operator(Tok.STAR_MUL, '*');
        value = self.convert(<>node.value);
        if isinstance(value, uni.Expr) {
            return uni.UnaryExpr(operand=value, op=star_tok, kid=[value, star_tok]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Subscript(expr):\n            value: expr\n            slice: _Slice\n            ctx: expr_context\n        """
    def proc_subscript(
        self: PyastBuildPass, <>node: py_ast.Subscript
    ) -> uni.AtomTrailer {
        value = self.convert(<>node.value);
        slice = self.convert(<>node.slice);
        if (not isinstance(slice, uni.IndexSlice) and isinstance(slice, uni.Expr)) {
            slice = uni.IndexSlice(
                slices=[uni.IndexSlice.Slice(slice, None, None)],
                is_range=False,
                kid=[slice]
            );
        }
        if (
            not isinstance(slice, uni.IndexSlice)
            and isinstance(slice, uni.TupleVal)
            and slice.values
        ) {
            slices: list[uni.IndexSlice.Slice] = [];
            for index_slice in slice.values {
                if not isinstance(index_slice, uni.IndexSlice) {
                    raise self.ice() ;
                }
                slices.append(index_slice.slices[0]);
            }
            slice = uni.IndexSlice(slices=slices, is_range=True, kid=[slice]);
        }
        if (isinstance(value, uni.Expr) and isinstance(slice, uni.IndexSlice)) {
            return uni.AtomTrailer(
                target=value,
                right=slice,
                is_attr=False,
                is_null_ok=False,
                kid=[value, slice]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class Try(stmt):\n            body: list[stmt]\n            handlers: list[ExceptHandler]\n            orelse: list[stmt]\n            finalbody: list[stmt]\n        """
    def proc_try(
        self: PyastBuildPass, <>node: (py_ast.Try | py_ast.TryStar)
    ) -> uni.TryStmt {
        body = [self.convert(i) for i in <>node.body];
        valid = [
            i
            for i in body
            if isinstance(i, uni.CodeBlockStmt)
        ];
        if (len(valid) != len(body)) {
            raise self.ice('Length mismatch in try body') ;
        }
        valid_body = valid;
        kid: list[uni.UniNode] = [*valid_body];
        if (len(<>node.handlers) != 0) {
            handlers = [self.convert(i) for i in <>node.handlers];
            valid_handlers = [
                i
                for i in handlers
                if isinstance(i, uni.Except)
            ];
            if (len(handlers) != len(valid_handlers)) {
                raise self.ice('Length mismatch in try handlers') ;
            }
            excepts = valid_handlers;
            kid.extend(valid_handlers);
        } else {
            excepts = [];
        }
        if (len(<>node.orelse) != 0) {
            orelse = [self.convert(i) for i in <>node.orelse];
            valid_orelse = [
                i
                for i in orelse
                if isinstance(i, uni.CodeBlockStmt)
            ];
            if (len(orelse) != len(valid_orelse)) {
                raise self.ice('Length mismatch in try orelse') ;
            }
            else_body = valid_orelse;
            elsestmt = uni.ElseStmt(body=else_body, kid=else_body);
            kid.extend(else_body);
        } else {
            else_body = None;
        }
        if (len(<>node.finalbody) != 0) {
            finalbody = [self.convert(i) for i in <>node.finalbody];
            valid_finalbody = [
                i
                for i in finalbody
                if isinstance(i, uni.CodeBlockStmt)
            ];
            if (len(finalbody) != len(valid_finalbody)) {
                raise self.ice('Length mismatch in try finalbody') ;
            }
            finally_stmt_obj: (uni.FinallyStmt | None) = (
                fin_append := uni.FinallyStmt(
                    body=valid_finalbody, kid=valid_finalbody
                )
            );
            kid.append(fin_append);
        } else {
            finally_stmt_obj = None;
        }
        ret = uni.TryStmt(
            body=valid_body,
            excepts=excepts,
            else_body=elsestmt if else_body else None,
            finally_body=finally_stmt_obj,
            kid=kid
        );
        return ret;
    }

    """Process python node.\n\n        class Try(stmt):\n            body: list[stmt]\n            handlers: list[ExceptHandler]\n            orelse: list[stmt]\n            finalbody: list[stmt]\n        """
    def proc_try_star(self: PyastBuildPass, <>node: py_ast.TryStar) -> uni.TryStmt {
        return self.proc_try(<>node);
    }

    """Process python node.\n\n        class Tuple(expr):\n            elts: list[expr]\n            ctx: expr_context\n        """
    def proc_tuple(self: PyastBuildPass, <>node: py_ast.Tuple) -> uni.TupleVal {
        elts = [self.convert(elt) for elt in <>node.elts];
        if (len(<>node.elts) != 0) {
            valid_elts = [
                i
                for i in elts
                if isinstance(i, (uni.Expr, uni.KWPair))
            ];
            if (len(elts) != len(valid_elts)) {
                raise self.ice('Length mismatch in tuple elts') ;
            }
            kid = elts;
        } else {
            l_paren = self.operator(Tok.LPAREN, '(');
            r_paren = self.operator(Tok.RPAREN, ')');
            valid_elts = [];
            kid = [l_paren, r_paren];
        }
        return uni.TupleVal(values=valid_elts, kid=kid);
    }

    """Process python node.\n\n        class Yield(expr):\n            value: expr | None\n        """
    def proc_yield(self: PyastBuildPass, <>node: py_ast.Yield) -> uni.YieldExpr {
        value = self.convert(<>node.value) if <>node.value else None;
        if isinstance(value, uni.Expr) {
            return uni.YieldExpr(expr=value, with_from=False, kid=[value]);
        } elif not value {
            return uni.YieldExpr(
                expr=None, with_from=False, kid=[self.operator(Tok.KW_YIELD, 'yield')]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node."""
    def proc_yield_from(
        self: PyastBuildPass, <>node: py_ast.YieldFrom
    ) -> uni.YieldExpr {
        value = self.convert(<>node.value);
        if isinstance(value, uni.Expr) {
            return uni.YieldExpr(expr=value, with_from=True, kid=[value]);
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class alias(AST):\n            name: _Identifier\n            asname: _Identifier | None\n        """
    def proc_alias(self: PyastBuildPass, <>node: py_ast.alias) -> uni.ExprAsItem {
        name = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value=<>node.name,
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(<>node.name)),
            pos_start=0,
            pos_end=0
        );
        asname = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value=<>node.asname,
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(<>node.asname)),
            pos_start=0,
            pos_end=0
        )
        if <>node.asname
        else None;
        return uni.ExprAsItem(
            expr=name, alias=asname, kid=[name, asname] if asname else [name]
        );
    }

    """Process python node.\n\n        class arg(AST):\n            arg: _Identifier\n            annotation: expr | None\n        """
    def proc_arg(self: PyastBuildPass, <>node: py_ast.arg) -> uni.ParamVar {
        import from jaclang.pycore.jac_parser { TOKEN_MAP }
        reserved_keywords = [
            v
            for (_, v) in TOKEN_MAP.items()
            if (v not in ['float', 'int', 'str', 'bool', 'self'])
        ];
        name = uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value=<>node.arg,
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + len(<>node.arg)),
            pos_start=0,
            pos_end=0,
            is_kwesc=(<>node.arg in reserved_keywords)
        );
        self.in_type_annotation = True;
        ann_expr = self.convert(<>node.annotation)
        if <>node.annotation
        else uni.Name(
            orig_src=self.orig_src,
            name=Tok.NAME,
            value='Any',
            line=<>node.lineno,
            end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
            col_start=<>node.col_offset,
            col_end=(<>node.col_offset + 3),
            pos_start=0,
            pos_end=0
        );
        self.in_type_annotation = False;
        if not isinstance(ann_expr, uni.Expr) {
            raise self.ice('Expected annotation to be an expression') ;
        }
        annot = uni.SubTag[uni.Expr](tag=ann_expr, kid=[ann_expr]);
        paramvar = uni.ParamVar(
            name=name, type_tag=annot, unpack=None, value=None, kid=[name, annot]
        );
        return paramvar;
    }

    """Process python node.\n\n        class arguments(AST):\n            posonlyargs: list[arg]\n            args: list[arg]\n            vararg: arg | None\n            kwonlyargs: list[arg]\n            kw_defaults: list[expr | None]\n            kwarg: arg | None\n            defaults: list[expr]\n        """
    def proc_arguments(
        self: PyastBuildPass, <>node: py_ast.arguments
    ) -> uni.FuncSignature {
        def _apply_kind(params: list, kind: uni.ParamKind) -> list {
            for param in params {
                cast(uni.ParamVar, param).param_kind = kind;
            }
            return params;
        }
        posonlyargs = _apply_kind(
            [self.convert(arg) for arg in <>node.posonlyargs], uni.ParamKind.POSONLY
        );
        args = _apply_kind(
            [self.convert(arg) for arg in <>node.args], uni.ParamKind.NORMAL
        );
        vararg_node = self.convert(<>node.vararg) if <>node.vararg else None;
        vararg: (uni.ParamVar | None) = None;
        if (vararg_node and isinstance(vararg_node, uni.ParamVar)) {
            vararg = vararg_node;
            vararg.param_kind = uni.ParamKind.VARARG;
            vararg.unpack = uni.Token(
                orig_src=self.orig_src,
                name=Tok.STAR_MUL,
                value='*',
                line=vararg.loc.first_line,
                end_line=vararg.loc.last_line,
                col_start=vararg.loc.col_start,
                col_end=vararg.loc.col_end,
                pos_start=0,
                pos_end=0
            );
            vararg.add_kids_left([vararg.unpack]);
        }
        kwonlyargs = _apply_kind(
            [self.convert(arg) for arg in <>node.kwonlyargs], uni.ParamKind.KWONLY
        );
        for i in range(len(kwonlyargs)) {
            kwa = kwonlyargs[i];
            kwd = <>node.kw_defaults[i];
            kwdefault = self.convert(kwd) if kwd else None;
            if (
                kwdefault
                and isinstance(kwa, uni.ParamVar)
                and isinstance(kwdefault, uni.Expr)
            ) {
                kwa.value = kwdefault;
                kwa.add_kids_right([kwa.value]);
            }
        }
        kwarg_node = self.convert(<>node.kwarg) if <>node.kwarg else None;
        kwarg: (uni.ParamVar | None) = None;
        if (kwarg_node and isinstance(kwarg_node, uni.ParamVar)) {
            kwarg = kwarg_node;
            kwarg.param_kind = uni.ParamKind.KWARG;
            kwarg.unpack = uni.Token(
                orig_src=self.orig_src,
                name=Tok.STAR_POW,
                value='**',
                line=kwarg.loc.first_line,
                end_line=kwarg.loc.last_line,
                col_start=kwarg.loc.col_start,
                col_end=kwarg.loc.col_end,
                pos_start=0,
                pos_end=0
            );
            kwarg.add_kids_left([kwarg.unpack]);
        }
        defaults = [self.convert(expr) for expr in <>node.defaults];
        for para in [*posonlyargs, *args][::-1] {
            if not defaults {
                break;
            }
            <>default = defaults.pop();
            if (
                <>default
                and isinstance(para, uni.ParamVar)
                and isinstance(<>default, uni.Expr)
            ) {
                para.value = <>default;
                para.add_kids_right([para.value]);
            }
        }
        if (kwonlyargs or args or posonlyargs or vararg or kwarg) {
            kids = [];
            kids.extend(posonlyargs) if posonlyargs else None;
            kids.extend(args) if args else None;
            kids.append(vararg) if vararg else None;
            kids.extend(kwonlyargs) if kwonlyargs else None;
            kids.append(kwarg) if kwarg else None;
            return uni.FuncSignature(
                posonly_params=posonlyargs,
                params=args,
                varargs=vararg,
                kwonlyargs=kwonlyargs,
                kwargs=kwarg,
                return_type=None,
                kid=kids
            );
        } else {
            return uni.FuncSignature(
                posonly_params=posonlyargs,
                params=[],
                varargs=vararg,
                kwonlyargs=kwonlyargs,
                kwargs=kwarg,
                return_type=None,
                kid=[self.operator(Tok.LPAREN, '('), self.operator(Tok.RPAREN, ')')]
            );
        }
    }

    """Create an operator token."""
    def operator(self: PyastBuildPass, tok: Tok, value: str) -> uni.Token {
        return uni.Token(
            orig_src=self.orig_src,
            name=tok,
            value=value,
            line=0,
            end_line=0,
            col_start=0,
            col_end=0,
            pos_start=0,
            pos_end=0
        );
    }

    """Process python node."""
    def proc_and(self: PyastBuildPass, <>node: py_ast.And) -> uni.Token {
        return self.operator(Tok.KW_AND, 'and');
    }

    """Process python node."""
    def proc_or(self: PyastBuildPass, <>node: py_ast.Or) -> uni.Token {
        return self.operator(Tok.KW_OR, 'or');
    }

    """Process python node."""
    def proc_add(self: PyastBuildPass, <>node: py_ast.Add) -> uni.Token {
        return self.operator(Tok.PLUS, '+');
    }

    """Process python node."""
    def proc_bit_and(self: PyastBuildPass, <>node: py_ast.BitAnd) -> uni.Token {
        return self.operator(Tok.BW_AND, '&');
    }

    """Process python node."""
    def proc_bit_or(self: PyastBuildPass, <>node: py_ast.BitOr) -> uni.Token {
        return self.operator(Tok.BW_OR, '|');
    }

    """Process python node."""
    def proc_bit_xor(self: PyastBuildPass, <>node: py_ast.BitXor) -> uni.Token {
        return self.operator(Tok.BW_XOR, '^');
    }

    """Process python node."""
    def proc_div(self: PyastBuildPass, <>node: py_ast.Div) -> uni.Token {
        return self.operator(Tok.DIV, '/');
    }

    """Process python node."""
    def proc_floor_div(self: PyastBuildPass, <>node: py_ast.FloorDiv) -> uni.Token {
        return self.operator(Tok.FLOOR_DIV, '//');
    }

    """Process python node."""
    def proc_l_shift(self: PyastBuildPass, <>node: py_ast.LShift) -> uni.Token {
        return self.operator(Tok.LSHIFT, '<<');
    }

    """Process python node."""
    def proc_mod(self: PyastBuildPass, <>node: py_ast.Mod) -> uni.Token {
        return self.operator(Tok.MOD, '%');
    }

    """Process python node."""
    def proc_mult(self: PyastBuildPass, <>node: py_ast.Mult) -> uni.Token {
        return self.operator(Tok.STAR_MUL, '*');
    }

    """Process python node."""
    def proc_mat_mult(self: PyastBuildPass, <>node: py_ast.MatMult) -> uni.Token {
        return self.operator(Tok.DECOR_OP, '@');
    }

    """Process python node."""
    def proc_pow(self: PyastBuildPass, <>node: py_ast.Pow) -> uni.Token {
        return self.operator(Tok.STAR_POW, '**');
    }

    """Process python node."""
    def proc_r_shift(self: PyastBuildPass, <>node: py_ast.RShift) -> uni.Token {
        return self.operator(Tok.RSHIFT, '>>');
    }

    """Process python node."""
    def proc_sub(self: PyastBuildPass, <>node: py_ast.Sub) -> uni.Token {
        return self.operator(Tok.MINUS, '-');
    }

    """Process python node."""
    def proc_invert(self: PyastBuildPass, <>node: py_ast.Invert) -> uni.Token {
        return self.operator(Tok.BW_NOT, '~');
    }

    """Process python node."""
    def proc_not(self: PyastBuildPass, <>node: py_ast.Not) -> uni.Token {
        return self.operator(Tok.NOT, 'not');
    }

    """Process python node."""
    def proc_u_add(self: PyastBuildPass, <>node: py_ast.UAdd) -> uni.Token {
        return self.operator(Tok.PLUS, '+');
    }

    """Process python node."""
    def proc_u_sub(self: PyastBuildPass, <>node: py_ast.USub) -> uni.Token {
        return self.operator(Tok.MINUS, '-');
    }

    """Process python node."""
    def proc_eq(self: PyastBuildPass, <>node: py_ast.Eq) -> uni.Token {
        return self.operator(Tok.EE, '==');
    }

    """Process python node."""
    def proc_gt(self: PyastBuildPass, <>node: py_ast.Gt) -> uni.Token {
        return self.operator(Tok.GT, '>');
    }

    """Process python node."""
    def proc_gt_e(self: PyastBuildPass, <>node: py_ast.GtE) -> uni.Token {
        return self.operator(Tok.GTE, '>=');
    }

    """Process python node."""
    def proc_in(self: PyastBuildPass, <>node: py_ast.In) -> uni.Token {
        return self.operator(Tok.KW_IN, 'in');
    }

    """Process python node."""
    def proc_is(self: PyastBuildPass, <>node: py_ast.Is) -> uni.Token {
        return self.operator(Tok.KW_IS, 'is');
    }

    """Process python node."""
    def proc_is_not(self: PyastBuildPass, <>node: py_ast.IsNot) -> uni.Token {
        return self.operator(Tok.KW_ISN, 'is not');
    }

    """Process python node."""
    def proc_lt(self: PyastBuildPass, <>node: py_ast.Lt) -> uni.Token {
        return self.operator(Tok.LT, '<');
    }

    """Process python node."""
    def proc_lt_e(self: PyastBuildPass, <>node: py_ast.LtE) -> uni.Token {
        return self.operator(Tok.LTE, '<=');
    }

    """Process python node."""
    def proc_not_eq(self: PyastBuildPass, <>node: py_ast.NotEq) -> uni.Token {
        return self.operator(Tok.NE, '!=');
    }

    """Process python node."""
    def proc_not_in(self: PyastBuildPass, <>node: py_ast.NotIn) -> uni.Token {
        return self.operator(Tok.KW_NIN, 'not in');
    }

    """Process python node.\n\n        class comprehension(AST):\n            target: expr\n            iter: expr\n            ifs: list[expr]\n            is_async: int\n        """
    def proc_comprehension(
        self: PyastBuildPass, <>node: py_ast.comprehension
    ) -> uni.InnerCompr {
        target = self.convert(<>node.target);
        iter = self.convert(<>node.iter);
        if (len(<>node.ifs) != 0) {
            ifs_list = [self.convert(ifs) for ifs in <>node.ifs];
            valid = [
                ifs
                for ifs in ifs_list
                if isinstance(ifs, uni.Expr)
            ];
        } else {
            valid = None;
        }
        is_async = <>node.is_async > 0;
        if (isinstance(target, uni.Expr) and isinstance(iter, uni.Expr)) {
            return uni.InnerCompr(
                is_async=is_async,
                target=target,
                collection=iter,
                conditional=valid,
                kid=[target, iter, *valid] if valid else [target, iter]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class keyword(AST):\n        if sys.version_info >= (3, 10):\n            __match_args__ = ("arg", "value")\n        arg: _Identifier | None\n        value: expr\n        """
    def proc_keyword(self: PyastBuildPass, <>node: py_ast.keyword) -> uni.KWPair {
        arg = None;
        if <>node.arg {
            import from jaclang.pycore.jac_parser { TOKEN_MAP }
            reserved_keywords = [v for (_, v) in TOKEN_MAP.items()];
            arg = uni.Name(
                orig_src=self.orig_src,
                name=Tok.NAME,
                value=<>node.arg,
                line=<>node.lineno,
                end_line=<>node.end_lineno if <>node.end_lineno else <>node.lineno,
                col_start=<>node.col_offset,
                col_end=(<>node.col_offset + len(<>node.arg if <>node.arg else '_')),
                pos_start=0,
                pos_end=0,
                is_kwesc=(<>node.arg in reserved_keywords)
            );
        }
        value = self.convert(<>node.value);
        if isinstance(value, uni.Expr) {
            return uni.KWPair(
                key=arg, value=value, kid=[arg, value] if arg else [value]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class match_case(AST):\n            pattern: _Pattern\n            guard: expr | None\n            body: list[stmt]\n        """
    def proc_match_case(
        self: PyastBuildPass, <>node: py_ast.match_case
    ) -> uni.MatchCase {
        pattern = self.convert(<>node.pattern);
        guard = self.convert(<>node.guard) if <>node.guard else None;
        body = [self.convert(i) for i in <>node.body];
        valid = [
            i
            for i in body
            if isinstance(i, uni.CodeBlockStmt)
        ];
        if (
            isinstance(pattern, uni.MatchPattern)
            and (isinstance(guard, uni.Expr) or (guard is None))
        ) {
            return uni.MatchCase(
                pattern=pattern,
                guard=guard,
                body=valid,
                kid=[pattern, guard, *valid] if guard else [pattern, *valid]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node.\n\n        class withitem(AST):\n            context_expr: expr\n            optional_vars: expr | None\n        """
    def proc_withitem(self: PyastBuildPass, <>node: py_ast.withitem) -> uni.ExprAsItem {
        context_expr = self.convert(<>node.context_expr);
        optional_vars = self.convert(<>node.optional_vars)
        if <>node.optional_vars
        else None;
        if (
            isinstance(context_expr, uni.Expr)
            and (isinstance(optional_vars, uni.Expr) or (optional_vars is None))
        ) {
            return uni.ExprAsItem(
                expr=context_expr,
                alias=optional_vars if optional_vars else None,
                kid=[context_expr, optional_vars] if optional_vars else [context_expr]
            );
        } else {
            raise self.ice() ;
        }
    }

    """Process python node."""
    def proc_param_spec(self: PyastBuildPass, <>node: py_ast.ParamSpec) -> None { }

    """Process python node."""
    def proc_type_alias(self: PyastBuildPass, <>node: py_ast.TypeAlias) -> None { }

    """Process python node."""
    def proc_type_var(self: PyastBuildPass, <>node: py_ast.TypeVar) -> None { }

    """Process python node."""
    def proc_type_var_tuple(self: PyastBuildPass, <>node: py_ast.TypeVarTuple) -> None { }

    """Convert a string to a docstring."""
    def convert_to_doc(self: PyastBuildPass, string: uni.String) -> None {
        string.value = f'"""{string.value[1:-1]}"""';
    }

    """aug_mapper."""
    def aug_op_map(self: PyastBuildPass, tok_dict: dict, op: uni.Token) -> str {
        op.value += '=';
        for (_key, value) in tok_dict.items() {
            if (value == op.value) {
                break;
            }
        }
        return _key;
    }
}

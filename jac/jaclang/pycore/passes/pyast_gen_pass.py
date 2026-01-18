"""Python AST Generation Pass for the Jac compiler.

This pass transforms the Jac AST into equivalent Python AST by:

1. Traversing the Jac AST and generating corresponding Python AST nodes
2. Handling all Jac language constructs and translating them to Python equivalents:
   - Classes, functions, and methods
   - Control flow statements (if/else, loops, try/except)
   - Data structures (lists, dictionaries, sets)
   - Special Jac features (walkers, abilities, archetypes)
   - Data spatial operations (node/edge connections)

3. Managing imports and dependencies between modules
4. Preserving source location information for error reporting
5. Generating appropriate Python code for Jac-specific constructs

The output of this pass is a complete Python AST representation that can be
compiled to Python bytecode or serialized to Python source code.
"""

import ast as ast3
import copy
import textwrap
from collections.abc import Sequence
from dataclasses import dataclass
from typing import ClassVar, TypeVar, cast

import jaclang.pycore.unitree as uni
from jaclang.pycore.constant import CodeContext, EdgeDir
from jaclang.pycore.constant import Constants as Con
from jaclang.pycore.constant import Tokens as Tok
from jaclang.pycore.passes.ast_gen import BaseAstGenPass
from jaclang.pycore.passes.ast_gen.jsx_processor import PyJsxProcessor

T = TypeVar("T", bound=ast3.AST)

# Mapping of Jac tokens to corresponding Python AST operator classes. This
# helps keep the implementation of ``exit_token`` concise and easier to
# maintain.
TOKEN_AST_MAP: dict[Tok, type[ast3.AST]] = {
    Tok.KW_AND: ast3.And,
    Tok.KW_OR: ast3.Or,
    Tok.PLUS: ast3.Add,
    Tok.ADD_EQ: ast3.Add,
    Tok.BW_AND: ast3.BitAnd,
    Tok.BW_AND_EQ: ast3.BitAnd,
    Tok.BW_OR: ast3.BitOr,
    Tok.BW_OR_EQ: ast3.BitOr,
    Tok.BW_XOR: ast3.BitXor,
    Tok.BW_XOR_EQ: ast3.BitXor,
    Tok.DIV: ast3.Div,
    Tok.DIV_EQ: ast3.Div,
    Tok.FLOOR_DIV: ast3.FloorDiv,
    Tok.FLOOR_DIV_EQ: ast3.FloorDiv,
    Tok.LSHIFT: ast3.LShift,
    Tok.LSHIFT_EQ: ast3.LShift,
    Tok.MOD: ast3.Mod,
    Tok.MOD_EQ: ast3.Mod,
    Tok.STAR_MUL: ast3.Mult,
    Tok.MUL_EQ: ast3.Mult,
    Tok.DECOR_OP: ast3.MatMult,
    Tok.MATMUL_EQ: ast3.MatMult,
    Tok.STAR_POW: ast3.Pow,
    Tok.STAR_POW_EQ: ast3.Pow,
    Tok.RSHIFT: ast3.RShift,
    Tok.RSHIFT_EQ: ast3.RShift,
    Tok.MINUS: ast3.Sub,
    Tok.SUB_EQ: ast3.Sub,
    Tok.BW_NOT: ast3.Invert,
    Tok.NOT: ast3.Not,
    Tok.EQ: ast3.NotEq,
    Tok.EE: ast3.Eq,
    Tok.GT: ast3.Gt,
    Tok.GTE: ast3.GtE,
    Tok.KW_IN: ast3.In,
    Tok.KW_IS: ast3.Is,
    Tok.KW_ISN: ast3.IsNot,
    Tok.LT: ast3.Lt,
    Tok.LTE: ast3.LtE,
    Tok.NE: ast3.NotEq,
    Tok.KW_NIN: ast3.NotIn,
}

# Mapping of unary operator tokens to their Python AST counterparts used in
# ``exit_unary_expr``.
UNARY_OP_MAP: dict[Tok, type[ast3.unaryop]] = {
    Tok.NOT: ast3.Not,
    Tok.BW_NOT: ast3.Invert,
    Tok.PLUS: ast3.UAdd,
    Tok.MINUS: ast3.USub,
}


class PyastGenPass(BaseAstGenPass[ast3.AST]):
    """Jac blue transpilation to python pass."""

    # Cached builtin names, shared across all instances
    _builtin_names: ClassVar[set[str] | None] = None

    @classmethod
    def _get_builtin_names(cls) -> set[str]:
        """Get the set of builtin names, cached after first successful access."""
        if cls._builtin_names is None:
            try:
                import jaclang.runtimelib.builtin as builtin_mod

                cls._builtin_names = set(builtin_mod.__all__)
            except (ImportError, AttributeError):
                # Builtin module not yet available during bootstrap
                return set()
        return cls._builtin_names

    def before_pass(self) -> None:
        self.child_passes: list[PyastGenPass] = self._init_child_passes(PyastGenPass)
        self.debuginfo: dict[str, list[str]] = {"jac_mods": []}
        self.already_added: list[str] = []
        self.jaclib_imports: set[str] = set()  # Track individual jaclib imports
        self.builtin_imports: set[str] = set()  # Track individual builtin imports
        self._temp_name_counter: int = 0
        self._hoisted_funcs: list[ast3.FunctionDef | ast3.AsyncFunctionDef] = []
        self.preamble: list[ast3.AST] = [
            self.sync(
                ast3.ImportFrom(
                    module="__future__",
                    names=[self.sync(ast3.alias(name="annotations", asname=None))],
                    level=0,
                ),
                jac_node=self.ir_out,
            ),
        ]
        self.jsx_processor = PyJsxProcessor(self)

    def enter_node(self, node: uni.UniNode) -> None:
        """Enter node."""
        # Prune ClientBlocks from Python generation
        if isinstance(node, uni.ClientBlock) or (
            isinstance(node, uni.ContextAwareNode)
            and node.code_context == CodeContext.CLIENT
            and (node.parent is None or isinstance(node.parent, uni.Module))
        ):
            self.prune()
            return
        if node.gen.py_ast:
            self.prune()
            return
        super().enter_node(node)

    def exit_node(self, node: uni.UniNode) -> None:
        """Exit node."""
        # ClientBlock handled in enter_node (pruned)
        # ServerBlock has its own exit handler (exit_server_block)
        if isinstance(node, uni.ClientBlock):
            return
        if (
            isinstance(node, uni.ContextAwareNode)
            and node.code_context == CodeContext.CLIENT
            and (node.parent is None or isinstance(node.parent, uni.Module))
        ):
            return
        super().exit_node(node)

    def jaclib_obj(self, obj_name: str) -> ast3.Name:
        """Return the object from jaclib as ast node based on the import config."""
        self.jaclib_imports.add(obj_name)
        return self.sync(ast3.Name(id=obj_name, ctx=ast3.Load()))

    def builtin_name(self, name: str) -> ast3.Name:
        """Return a builtin name and track it for importing.

        Note: Some names like 'Enum' are provided by other imports (e.g., needs_enum)
        and should not be added to builtin_imports.
        """
        # Enum is imported via needs_enum, not from builtins
        if name not in ["Enum"]:
            self.builtin_imports.add(name)
        return self.sync(ast3.Name(id=name, ctx=ast3.Load()))

    def _add_preamble_once(self, key: str, node: ast3.AST) -> None:
        """Append an import statement to the preamble once."""
        if key in self.already_added:
            return
        self.preamble.append(self.sync(node, jac_node=self.ir_out))
        self.already_added.append(key)

    def needs_typing(self) -> None:
        """Ensure typing is imported only once."""
        self._add_preamble_once(
            self.needs_typing.__name__,
            ast3.Import(
                names=[self.sync(ast3.alias(name="typing"), jac_node=self.ir_out)]
            ),
        )

    def needs_enum(self) -> None:
        """Ensure Enum utilities are imported only once."""
        self._add_preamble_once(
            self.needs_enum.__name__,
            ast3.ImportFrom(
                module="enum",
                names=[
                    self.sync(ast3.alias(name="Enum", asname=None)),
                    self.sync(ast3.alias(name="auto", asname=None)),
                ],
                level=0,
            ),
        )

    def needs_future(self) -> None:
        """Ensure concurrent Future is imported only once."""
        self._add_preamble_once(
            self.needs_future.__name__,
            ast3.ImportFrom(
                module="concurrent.futures",
                names=[self.sync(ast3.alias(name="Future", asname=None))],
                level=0,
            ),
        )

    def _next_temp_name(self, prefix: str) -> str:
        """Generate a deterministic temporary name for synthesized definitions."""
        self._temp_name_counter += 1
        return f"__jac_{prefix}_{self._temp_name_counter}"

    def _function_expr_from_def(
        self,
        func_def: ast3.FunctionDef | ast3.AsyncFunctionDef,
        jac_node: uni.UniNode,
        filename_hint: str,
    ) -> ast3.Name:
        """Convert a synthesized function definition into an executable expression.

        Instead of using make_block_lambda at runtime, we hoist the function
        definition to be emitted before the current statement, then return
        a reference to the function name.
        """
        # Ensure locations are fixed
        ast3.fix_missing_locations(func_def)
        # Add the function to the hoisted list - it will be emitted before the current statement
        self._hoisted_funcs.append(func_def)
        # Return a reference to the function name
        return self.sync(
            ast3.Name(id=func_def.name, ctx=ast3.Load()),
            jac_node=jac_node,
        )

    def _get_sem_decorator(self, node: uni.UniNode) -> ast3.Call | None:
        """Create a semstring decorator for the given semantic strings.

        Example:
            @_.sem(
                "Returns the weather for a given city.", {
                    "city" : "Name of the city to get the weather for.",
                }
            )
            def get_weather(city: str) {}

        This the second parameter (dict) will also used in the class `has` variables
        enum values etc.
        """
        semstr: str = ""
        inner_semstr: dict[str, str] = {}

        if isinstance(node, uni.Archetype):
            semstr = node.semstr
            arch_ast_body: list[uni.UniNode] = []
            if isinstance(node.body, list):
                arch_ast_body = node.body
            elif isinstance(node.body, uni.ImplDef) and isinstance(
                node.body.body, list
            ):
                # Type check will fail because of the invariant between codeblock and enum block
                # but since we're only reading the list (and python doesn't have const) the type
                # error is irrelevent here.
                arch_ast_body = node.body.body  # type: ignore
            for stmt in arch_ast_body:
                if isinstance(stmt, uni.ArchHas):
                    for has_var in stmt.vars:
                        if has_var.semstr:
                            inner_semstr[has_var.sym_name] = has_var.semstr
        elif isinstance(node, uni.Enum):
            semstr = node.semstr
            enum_ast_body: list[uni.UniNode] = []
            if isinstance(node.body, list):
                enum_ast_body = node.body
            elif isinstance(node.body, uni.ImplDef) and isinstance(
                node.body.body, list
            ):
                enum_ast_body = node.body.body  # type: ignore
            for stmt in enum_ast_body:
                if isinstance(stmt, uni.Assignment) and isinstance(
                    stmt.target[0], uni.AstSymbolNode
                ):
                    name = stmt.target[0].sym_name
                    val_semstr = stmt.target[0].semstr
                    inner_semstr[name] = val_semstr
        elif isinstance(node, uni.Ability):
            semstr = node.semstr
            inner_semstr = (
                {
                    param.sym_name: param.semstr
                    for param in node.signature.params
                    if param.semstr
                }
                if isinstance(node.signature, uni.FuncSignature)
                else {}
            )

        # Only add sem decorator if there's actual semantic content
        if not semstr and (
            not inner_semstr or all(not v for v in inner_semstr.values())
        ):
            return None

        return self.sync(
            ast3.Call(
                func=self.jaclib_obj("sem"),
                args=[
                    self.sync(ast3.Constant(value=semstr)),
                    self.sync(
                        ast3.Dict(
                            keys=[
                                self.sync(ast3.Constant(value=k)) for k in inner_semstr
                            ],
                            values=[
                                self.sync(ast3.Constant(value=v))
                                for v in inner_semstr.values()
                            ],
                        )
                    ),
                ],
                keywords=[],
            )
        )

    def sync(
        self, py_node: T, jac_node: uni.UniNode | None = None, deep: bool = False
    ) -> T:
        """Sync ast locations."""
        if not jac_node:
            jac_node = self.cur_node
        for i in ast3.walk(py_node) if deep else [py_node]:
            # TODO:here we are type ignore to hack the mypy bcz
            # python AST dosen't have lineno, col_offset, end_lineno, end_col_offset attributes.
            # we need to discuss with @marsninja
            if isinstance(i, ast3.AST):
                i.lineno = jac_node.loc.first_line  # type:ignore[attr-defined]
                i.col_offset = jac_node.loc.col_start  # type:ignore[attr-defined]
                i.end_lineno = (  # type:ignore[attr-defined]
                    jac_node.loc.last_line
                    if jac_node.loc.last_line
                    and (jac_node.loc.last_line > jac_node.loc.first_line)
                    else jac_node.loc.first_line
                )
                i.end_col_offset = (  # type:ignore[attr-defined]
                    jac_node.loc.col_end
                    if jac_node.loc.col_end
                    and (jac_node.loc.col_end > jac_node.loc.col_start)
                    else jac_node.loc.col_start
                )
                i.jac_link: list[ast3.AST] = [jac_node]  # type: ignore
        return py_node

    def pyinline_sync(
        self,
        py_nodes: list[ast3.AST],
    ) -> list[ast3.AST]:
        """Sync ast locations."""
        for node in py_nodes:
            for i in ast3.walk(node):
                if isinstance(i, ast3.AST):
                    if hasattr(i, "lineno") and i.lineno is not None:
                        i.lineno += self.cur_node.loc.first_line
                    if hasattr(i, "end_lineno") and i.end_lineno is not None:
                        i.end_lineno += self.cur_node.loc.first_line
                    i.jac_link: ast3.AST = [self.cur_node]  # type: ignore
        return py_nodes

    def resolve_switch_pattern(
        self, pattern: uni.MatchPattern, target: uni.Expr
    ) -> ast3.expr:
        """Resolve switch case pattern."""
        if isinstance(pattern, uni.MatchValue):
            return self.sync(
                ast3.Compare(
                    left=cast(ast3.expr, target.gen.py_ast[0]),
                    ops=[self.sync(ast3.Eq())],
                    comparators=[cast(ast3.expr, pattern.value.gen.py_ast[0])],
                )
            )
        elif isinstance(pattern, uni.MatchOr):
            return self.sync(
                ast3.BoolOp(
                    op=self.sync(ast3.Or()),
                    values=[
                        self.resolve_switch_pattern(pat, target)
                        for pat in pattern.patterns
                    ],
                )
            )
        elif isinstance(pattern, uni.MatchSingleton):
            return self.sync(
                ast3.Compare(
                    left=cast(ast3.expr, target.gen.py_ast[0]),
                    ops=[self.sync(ast3.Is())],
                    comparators=[cast(ast3.expr, pattern.value.gen.py_ast[0])],
                )
            )
        # elif isinstance(pattern, uni.MatchAs):
        #     pass
        # elif isinstance(pattern, uni.MatchSequence):
        #     pass
        # elif isinstance(pattern, uni.MatchMapping):
        #     pass
        # elif isinstance(pattern, uni.MatchKVPair):
        #     pass
        # elif isinstance(pattern, uni.MatchStar):
        #     pass
        # elif isinstance(pattern, uni.MatchArch):
        #     pass
        else:
            raise self.ice("Unsupported switch pattern type")

    def resolve_switch_stmt(self, node: uni.SwitchStmt) -> list[ast3.AST]:
        """Resolve switch statement."""
        var_executed = self.sync(ast3.Name(id="__executed", ctx=ast3.Store()))
        assign_var = self.sync(
            ast3.Assign(
                targets=[var_executed], value=self.sync(ast3.Constant(value=False))
            )
        )
        ast_nodes: list[ast3.AST] = []
        test_expr: ast3.expr
        executed_assign = self.sync(
            ast3.Assign(
                targets=[var_executed], value=self.sync(ast3.Constant(value=True))
            )
        )
        for case in node.cases:
            if case.pattern is None:
                # default case
                ast_nodes.extend(self.resolve_stmt_block(case.body) + [executed_assign])
            else:
                test_expr = self.sync(
                    ast3.BoolOp(
                        op=self.sync(ast3.Or()),
                        values=[
                            self.resolve_switch_pattern(case.pattern, node.target),
                            self.sync(ast3.Name(id="__executed", ctx=ast3.Load())),
                        ],
                    )
                )
                if_stmt = self.sync(
                    ast3.If(
                        test=test_expr,
                        body=cast(
                            list[ast3.stmt],
                            self.resolve_stmt_block(case.body) + [executed_assign],
                        ),
                        orelse=[],
                    )
                )
                ast_nodes.append(if_stmt)
        while_cond = self.sync(
            ast3.UnaryOp(
                op=self.sync(ast3.Not()),
                operand=self.sync(ast3.Name(id="__executed", ctx=ast3.Load())),
            )
        )
        return [
            assign_var,
            self.sync(
                ast3.While(
                    test=while_cond, body=cast(list[ast3.stmt], ast_nodes), orelse=[]
                )
            ),
        ]

    def resolve_stmt_block(
        self,
        node: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None,
        doc: uni.String | None = None,
    ) -> list[ast3.AST]:
        """Unwind codeblock."""
        items = list(node) if node else []
        valid_stmts = [i for i in items if not isinstance(i, uni.Semi)]
        ret: list[ast3.AST] = (
            [self.sync(ast3.Pass())]
            if isinstance(node, Sequence) and not valid_stmts
            else (
                self._flatten_ast_list(
                    [
                        (
                            x.gen.py_ast
                            if not isinstance(x, uni.SwitchStmt)
                            else self.resolve_switch_stmt(x)
                        )
                        for x in valid_stmts
                        if not isinstance(x, uni.ImplDef)
                    ]
                )
                if node is not None
                else []
            )
        )
        if doc:
            ret = [
                self.sync(
                    ast3.Expr(value=cast(ast3.expr, doc.gen.py_ast[0])), jac_node=doc
                ),
                *ret,
            ]
        return ret

    def sync_many(self, py_nodes: list[T], jac_node: uni.UniNode) -> list[T]:
        """Sync ast locations."""
        for py_node in py_nodes:
            self.sync(py_node, jac_node)
        return py_nodes

    def list_to_attrib(
        self, attribute_list: list[str], sync_node_list: Sequence[uni.UniNode]
    ) -> ast3.AST:
        """Convert list to attribute."""
        attr_node: ast3.Name | ast3.Attribute = self.sync(
            ast3.Name(id=attribute_list[0], ctx=ast3.Load()), sync_node_list[0]
        )
        for attr, sync_node in zip(
            attribute_list[1:], sync_node_list[1:], strict=False
        ):
            attr_node = self.sync(
                ast3.Attribute(value=attr_node, attr=attr, ctx=ast3.Load()),
                sync_node,
            )
        return attr_node

    def exit_sub_tag(self, node: uni.SubTag[uni.T]) -> None:
        node.gen.py_ast = node.tag.gen.py_ast

    def exit_module(self, node: uni.Module) -> None:
        # Merge jaclib and builtin imports from child passes
        for child_pass in self.child_passes:
            self.jaclib_imports.update(child_pass.jaclib_imports)
            self.builtin_imports.update(child_pass.builtin_imports)

        # Add builtin imports if any were used
        # Skip when compiling the builtin module itself to avoid self-referential imports
        is_builtin_module = (
            node.loc.mod_path.endswith(("builtin.jac", "builtin.py"))
            and "runtimelib" in node.loc.mod_path
        )
        if self.builtin_imports and not is_builtin_module:
            self.preamble.append(
                self.sync(
                    ast3.ImportFrom(
                        module="jaclang.runtimelib.builtin",
                        names=[
                            self.sync(ast3.alias(name=name, asname=None))
                            for name in sorted(self.builtin_imports)
                        ],
                        level=0,
                    ),
                    jac_node=self.ir_out,
                )
            )

        # Add library imports at the end of preamble
        # Skip when compiling jaclang.lib itself to avoid self-referential imports.
        mod_path_norm = node.loc.mod_path.replace("\\", "/")
        is_jaclib_module = mod_path_norm.endswith(
            ("/jaclang/lib.jac", "/jaclang/lib.py")
        )
        if self.jaclib_imports and not is_jaclib_module:
            self.preamble.append(
                self.sync(
                    ast3.ImportFrom(
                        module="jaclang.pycore.jaclib",
                        names=[
                            self.sync(ast3.alias(name=name, asname=None))
                            for name in sorted(self.jaclib_imports)
                        ],
                        level=0,
                    ),
                    jac_node=self.ir_out,
                )
            )

        merged_body = self._merge_module_bodies(node)
        body_items: list[ast3.AST | list[ast3.AST] | None] = []

        # If there's a docstring, it must come first (before __future__ imports)
        if node.doc:
            doc_stmt = self.sync(
                ast3.Expr(value=cast(ast3.expr, node.doc.gen.py_ast[0])),
                jac_node=node.doc,
            )
            body_items.append(doc_stmt)

        # Add preamble (which includes __future__ imports) after docstring
        body_items.extend(self.preamble)
        body_items.extend(item.gen.py_ast for item in merged_body)

        new_body = self._flatten_ast_list(body_items)
        node.gen.py_ast = [
            self.sync(
                ast3.Module(
                    body=[cast(ast3.stmt, s) for s in new_body],
                    type_ignores=[],
                )
            )
        ]
        node.gen.py = ast3.unparse(node.gen.py_ast[0])

    def exit_global_vars(self, node: uni.GlobalVars) -> None:
        if node.doc:
            doc = self.sync(
                ast3.Expr(value=cast(ast3.expr, node.doc.gen.py_ast[0])),
                jac_node=node.doc,
            )
            assigns_ast: list[ast3.AST] = self._flatten_ast_list(
                [a.gen.py_ast for a in node.assignments]
            )
            if isinstance(doc, ast3.AST):
                node.gen.py_ast = [doc] + assigns_ast
            else:
                raise self.ice()
        else:
            node.gen.py_ast = self._flatten_ast_list(
                [a.gen.py_ast for a in node.assignments]
            )

    def exit_test(self, node: uni.Test) -> None:
        test_name = node.name.sym_name
        func = self.sync(
            ast3.FunctionDef(
                name=test_name,
                args=self.sync(
                    ast3.arguments(
                        posonlyargs=[],
                        args=[
                            self.sync(
                                ast3.arg(arg=Con.JAC_CHECK.value, annotation=None)
                            )
                        ],
                        kwonlyargs=[],
                        vararg=None,
                        kwarg=None,
                        kw_defaults=[],
                        defaults=[],
                    )
                ),
                body=[
                    cast(ast3.stmt, stmt)
                    for stmt in self.resolve_stmt_block(node.body, doc=node.doc)
                ],
                decorator_list=[self.jaclib_obj("jac_test")],
                returns=self.sync(ast3.Constant(value=None)),
                type_comment=None,
                type_params=[],
            ),
        )
        if node.loc.mod_path.endswith(".test.jac"):
            func.decorator_list.append(
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("impl_patch_filename"),
                        args=[],
                        keywords=[
                            self.sync(
                                ast3.keyword(
                                    arg="file_loc",
                                    value=self.sync(
                                        ast3.Constant(value=node.loc.mod_path)
                                    ),
                                )
                            ),
                        ],
                    )
                )
            )
        node.gen.py_ast = [func]

    def exit_module_code(self, node: uni.ModuleCode) -> None:
        node.gen.py_ast = self.resolve_stmt_block(node.body, doc=node.doc)
        if node.name:
            node.gen.py_ast = [
                self.sync(
                    ast3.If(
                        test=self.sync(
                            ast3.Compare(
                                left=self.sync(
                                    ast3.Name(id="__name__", ctx=ast3.Load())
                                ),
                                ops=[self.sync(ast3.Eq())],
                                comparators=[
                                    self.sync(ast3.Constant(value=node.name.sym_name))
                                ],
                            )
                        ),
                        body=[cast(ast3.stmt, i) for i in node.gen.py_ast],
                        orelse=[],
                    )
                )
            ]

    def exit_client_block(self, node: uni.ClientBlock) -> None:
        """Handle ClientBlock - already set to empty in enter_node."""
        # py_ast already set to [] in enter_node, nothing to do here
        pass

    def exit_server_block(self, node: uni.ServerBlock) -> None:
        """Handle ServerBlock - unwrap its children to module level."""
        # Collect all py_ast from children to expose at module level
        node.gen.py_ast = self._flatten_ast_list(
            [item.gen.py_ast for item in node.body]
        )

    def exit_py_inline_code(self, node: uni.PyInlineCode) -> None:
        if node.doc:
            doc = self.sync(
                ast3.Expr(value=cast(ast3.expr, node.doc.gen.py_ast[0])),
                jac_node=node.doc,
            )
            if isinstance(doc, ast3.AST):
                node.gen.py_ast = self.pyinline_sync(
                    [doc, *ast3.parse(node.code.value).body]
                )

            else:
                raise self.ice()
        else:
            node.gen.py_ast = self.pyinline_sync(
                [*ast3.parse(textwrap.dedent(node.code.value)).body]
            )

    def exit_import(self, node: uni.Import) -> None:
        """Exit import node."""
        # Skip __future__ imports as we always add them in the preamble
        # This prevents duplicate __future__ imports which cause SyntaxError
        if node.from_loc and node.from_loc.path:
            module_parts = [p.value for p in node.from_loc.path if hasattr(p, "value")]
            if module_parts == ["__future__"]:
                node.gen.py_ast = []
                return

        py_nodes: list[ast3.AST] = []
        if node.doc:
            py_nodes.append(
                self.sync(
                    ast3.Expr(value=cast(ast3.expr, node.doc.gen.py_ast[0])),
                    jac_node=node.doc,
                )
            )

        if node.is_absorb:
            # This is `include "module_name";` which becomes `from module_name import *`
            source = node.items[0]
            if not isinstance(source, uni.ModulePath):
                raise self.ice()

            module_name_parts = [p.value for p in source.path] if source.path else []
            module_name = ".".join(module_name_parts) if module_name_parts else None

            py_nodes.append(
                self.sync(
                    py_node=ast3.ImportFrom(
                        module=module_name,
                        names=[self.sync(ast3.alias(name="*"), node)],
                        level=source.level,
                    ),
                    jac_node=node,
                )
            )
        elif not node.from_loc:
            # This is `import module1, module2 as alias;`
            py_nodes.append(
                self.sync(
                    ast3.Import(
                        names=[
                            cast(ast3.alias, x)
                            for item in node.items
                            for x in item.gen.py_ast
                        ]
                    )
                )
            )
        else:
            # This is `from module import item1, item2 as alias;`
            module_name_parts = (
                [p.value for p in node.from_loc.path] if node.from_loc.path else []
            )
            module_name = ".".join(module_name_parts) if module_name_parts else None

            py_nodes.append(
                self.sync(
                    ast3.ImportFrom(
                        module=module_name,
                        names=[
                            cast(ast3.alias, i)
                            for item in node.items
                            for i in item.gen.py_ast
                        ],
                        level=node.from_loc.level,
                    )
                )
            )
        node.gen.py_ast = py_nodes

    def exit_module_path(self, node: uni.ModulePath) -> None:
        # Check if this is a string literal import in a non-client context
        if node.path and len(node.path) == 1 and isinstance(node.path[0], uni.String):
            # String literal imports are only supported in client (cl) imports
            import_node = node.parent_of_type(uni.Import)
            if import_node and import_node.code_context != CodeContext.CLIENT:
                self.log_error(
                    f'String literal imports (e.g., from "{node.path[0].lit_value}") are only supported '
                    f"in client (cl) imports, not Python imports. "
                    f"Use 'cl import from \"{node.path[0].lit_value}\" {{ ... }}' instead.",
                    node,
                )

        node.gen.py_ast = [
            self.sync(
                ast3.alias(
                    name=f"{node.dot_path_str}",
                    asname=node.alias.sym_name if node.alias else None,
                )
            )
        ]

    def exit_module_item(self, node: uni.ModuleItem) -> None:
        # Validate that default and namespace imports are only used in cl imports
        if isinstance(node.name, uni.Token) and node.name.value in ["default", "*"]:
            import_node = node.from_parent
            if import_node.code_context != CodeContext.CLIENT:
                import_type = "Default" if node.name.value == "default" else "Namespace"
                self.log_error(
                    f"{import_type} imports (using '{node.name.value}') are only supported "
                    f"in client (cl) imports, not Python imports",
                    node,
                )
                # Skip generating Python AST for invalid imports
                node.gen.py_ast = []
                return

        # Generate Python AST for regular imports
        node.gen.py_ast = [
            self.sync(
                ast3.alias(
                    name=f"{node.name.sym_name if isinstance(node.name, uni.Name) else node.name.value}",
                    asname=node.alias.sym_name if node.alias else None,
                )
            )
        ]

    def enter_archetype(self, node: uni.Archetype) -> None:
        if isinstance(node.body, uni.ImplDef):
            self.traverse(node.body)

    def exit_archetype(self, node: uni.Archetype) -> None:
        inner: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None = None
        if isinstance(node.body, uni.ImplDef):
            inner = node.body.body if not isinstance(node.body.body, uni.Expr) else None
        elif not isinstance(node.body, uni.Expr):
            inner = node.body
        body: list[ast3.AST] = self.resolve_stmt_block(inner, doc=node.doc)
        if not body and not isinstance(node.body, uni.Expr):
            self.log_error(
                "Archetype has no body. Perhaps an impl must be imported.", node
            )
            body = [self.sync(ast3.Pass(), node)]
        if node.is_async:
            body.insert(
                0,
                self.sync(
                    ast3.Assign(
                        targets=[
                            self.sync(ast3.Name(id="__jac_async__", ctx=ast3.Store()))
                        ],
                        value=self.sync(ast3.Constant(value=node.is_async)),
                    )
                ),
            )

        decorators = (
            [cast(ast3.expr, i.gen.py_ast[0]) for i in node.decorators]
            if node.decorators
            else []
        )

        if sem_decorator := self._get_sem_decorator(node):
            decorators.append(sem_decorator)

        base_classes = [cast(ast3.expr, i.gen.py_ast[0]) for i in node.base_classes]
        if node.arch_type.name != Tok.KW_CLASS:
            base_classes.append(self.jaclib_obj(node.arch_type.value.capitalize()))

        class_def = self.sync(
            ast3.ClassDef(
                name=node.name.sym_name,
                bases=[cast(ast3.expr, i) for i in base_classes],
                keywords=[],
                body=[cast(ast3.stmt, i) for i in body],
                decorator_list=[cast(ast3.expr, i) for i in decorators],
                type_params=[],
            )
        )
        node.gen.py_ast = [class_def]

    def enter_enum(self, node: uni.Enum) -> None:
        if isinstance(node.body, uni.ImplDef):
            self.traverse(node.body)

    def exit_enum(self, node: uni.Enum) -> None:
        self.needs_enum()
        inner: Sequence[uni.CodeBlockStmt] | Sequence[uni.EnumBlockStmt] | None = None
        if isinstance(node.body, uni.ImplDef):
            inner = node.body.body if not isinstance(node.body.body, uni.Expr) else None
        elif not isinstance(node.body, uni.Expr):
            inner = node.body
        body = self.resolve_stmt_block(inner, doc=node.doc)
        decorators = (
            [cast(ast3.expr, i.gen.py_ast[0]) for i in node.decorators]
            if node.decorators
            else []
        )

        if sem_decorator := self._get_sem_decorator(node):
            decorators.append(sem_decorator)

        base_classes = [cast(ast3.expr, i.gen.py_ast[0]) for i in node.base_classes]
        base_classes.append(self.builtin_name("Enum"))
        class_def = self.sync(
            ast3.ClassDef(
                name=node.name.sym_name,
                bases=[cast(ast3.expr, i) for i in base_classes],
                keywords=[],
                body=[cast(ast3.stmt, i) for i in body],
                decorator_list=[cast(ast3.expr, i) for i in decorators],
                type_params=[],
            )
        )
        node.gen.py_ast = [class_def]

    def enter_ability(self, node: uni.Ability) -> None:
        if isinstance(node.body, uni.ImplDef):
            self.traverse(node.body)

    def _invoke_llm_call(
        self, model: ast3.expr, caller: ast3.expr, args: ast3.Dict
    ) -> ast3.Call:
        """Reusable method to codegen call_llm(model, caller, args)."""
        mtir_ast = self.sync(
            ast3.Call(
                func=self.jaclib_obj("get_mtir"),
                args=[],
                keywords=[
                    self.sync(
                        ast3.keyword(
                            arg="caller",
                            value=caller,
                        )
                    ),
                    self.sync(
                        ast3.keyword(
                            arg="args",
                            value=args,
                        )
                    ),
                    self.sync(
                        ast3.keyword(
                            arg="call_params",
                            value=self.sync(
                                ast3.Attribute(
                                    value=model,
                                    attr="call_params",
                                    ctx=ast3.Load(),
                                ),
                            ),
                        )
                    ),
                ],
            )
        )
        return self.sync(
            ast3.Call(
                func=self.jaclib_obj("call_llm"),
                args=[],
                keywords=[
                    self.sync(
                        ast3.keyword(
                            arg="model",
                            value=model,
                        )
                    ),
                    self.sync(
                        ast3.keyword(
                            arg="mtir",
                            value=mtir_ast,
                        )
                    ),
                ],
            )
        )

    def gen_llm_body(self, node: uni.Ability) -> list[ast3.stmt]:
        """Generate the by LLM body."""
        assert isinstance(node.signature, uni.FuncSignature)

        model_expr: ast3.expr
        if (
            node.signature.return_type
            and isinstance(node.signature.return_type, uni.BinaryExpr)
            and isinstance(node.signature.return_type.op, uni.Token)
            and node.signature.return_type.op.name == Tok.KW_BY
        ):
            model_expr = cast(ast3.expr, node.signature.return_type.right.gen.py_ast[0])
        elif isinstance(node.body, uni.Expr):
            model_expr = cast(ast3.expr, node.body.gen.py_ast[0])
        else:
            raise self.ice("gen_llm_body called without model expression")

        # Codegen for the caller of the LLM call.
        caller: ast3.expr
        if node.method_owner:
            owner = self.sync(
                ast3.Name(
                    id="self" if not node.is_static else node.method_owner.sym_name,
                    ctx=ast3.Load(),
                ),
                jac_node=node.method_owner,
            )
            caller = self.sync(
                ast3.Attribute(
                    value=owner,
                    attr=node.name_ref.sym_name,
                    ctx=ast3.Load(),
                ),
                jac_node=node.method_owner,
            )
        else:
            caller = self.sync(ast3.Name(node.name_ref.sym_name, ctx=ast3.Load()))

        # Codegen for arguments of the function.
        #
        # TODO: Currently this doesn't consider *args or **kwargs (but this also
        # same in the current version so we're not breaking anything).
        args = self.sync(
            ast3.Dict(
                keys=[
                    self.sync(ast3.Constant(value=param.name.sym_name))
                    for param in node.signature.params
                ],
                values=[
                    self.sync(ast3.Name(param.name.sym_name, ctx=ast3.Load()))
                    for param in node.signature.params
                ],
            )
        )

        llm_call = self._invoke_llm_call(model=model_expr, caller=caller, args=args)

        # Attach docstring if exists and the llm call.
        statements: list[ast3.stmt] = []
        if node.doc:
            statements.append(
                self.sync(
                    ast3.Expr(
                        value=self.sync(
                            ast3.Constant(value=node.doc.lit_value),
                            jac_node=node.doc,
                        )
                    )
                )
            )
        statements.append(self.sync(ast3.Return(value=llm_call)))
        return statements

    def exit_ability(self, node: uni.Ability) -> None:
        func_type = ast3.AsyncFunctionDef if node.is_async else ast3.FunctionDef
        # Check if return type has 'by' operator for LLM-augmented function
        has_by_in_return = (
            isinstance(node.signature, uni.FuncSignature)
            and node.signature.return_type
            and isinstance(node.signature.return_type, uni.BinaryExpr)
            and isinstance(node.signature.return_type.op, uni.Token)
            and node.signature.return_type.op.name == Tok.KW_BY
        )
        body = (
            self.gen_llm_body(node)
            if isinstance(node.body, uni.Expr)
            or (
                isinstance(node.body, uni.ImplDef)
                and isinstance(node.body.body, uni.Expr)
            )
            or has_by_in_return
            else (
                [
                    self.sync(
                        ast3.Expr(value=cast(ast3.expr, node.doc.gen.py_ast[0])),
                        jac_node=node.doc,
                    ),
                    self.sync(ast3.Pass(), node.body),
                ]
                if node.doc and node.is_abstract
                else (
                    [self.sync(ast3.Pass(), node.body)]
                    if node.is_abstract
                    else self.resolve_stmt_block(
                        (
                            node.body.body
                            if isinstance(node.body, uni.ImplDef)
                            and not isinstance(node.body.body, uni.Expr)
                            else (
                                node.body
                                if not isinstance(node.body, uni.Expr)
                                else None
                            )
                        ),
                        doc=node.doc,
                    )
                )
            )
        )
        if node.is_abstract and node.body:
            self.log_error(
                f"Abstract ability {node.sym_name} should not have a body.",
                node,
            )
        decorator_list = (
            [cast(ast3.expr, i.gen.py_ast[0]) for i in node.decorators]
            if node.decorators
            else []
        )

        if sem_decorator := self._get_sem_decorator(node):
            decorator_list.append(sem_decorator)

        if isinstance(node.signature, uni.EventSignature):
            decorator_list.append(
                self.jaclib_obj(
                    "on_entry"
                    if node.signature.event.name == Tok.KW_ENTRY
                    else "on_exit"
                )
            )

        if isinstance(node.body, uni.ImplDef):
            decorator_list.append(
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("impl_patch_filename"),
                        args=[self.sync(ast3.Constant(value=node.body.loc.mod_path))],
                        keywords=[],
                    )
                )
            )
        if node.is_abstract:
            decorator_list.append(self.builtin_name("abstractmethod"))
        if node.is_override:
            decorator_list.append(self.builtin_name("override"))
        if node.is_static:
            decorator_list.insert(
                0, self.sync(ast3.Name(id="staticmethod", ctx=ast3.Load()))
            )
        if not body and not isinstance(node.body, uni.Expr):
            self.log_error(
                "Ability has no body. Perhaps an impl must be imported.", node
            )
            body = [self.sync(ast3.Pass(), node)]  # type: ignore

        ast_returns: ast3.expr = self.sync(ast3.Constant(value=None))
        if isinstance(node.signature, uni.FuncSignature) and node.signature.return_type:
            if (
                isinstance(node.signature.return_type, uni.BinaryExpr)
                and isinstance(node.signature.return_type.op, uni.Token)
                and node.signature.return_type.op.name == Tok.KW_BY
            ):
                ast_returns = cast(
                    ast3.expr, node.signature.return_type.left.gen.py_ast[0]
                )
            else:
                ast_returns = cast(ast3.expr, node.signature.return_type.gen.py_ast[0])

        func_def = self.sync(
            func_type(
                name=node.name_ref.sym_name,
                args=(
                    cast(ast3.arguments, node.signature.gen.py_ast[0])
                    if node.signature
                    else self.sync(
                        ast3.arguments(
                            posonlyargs=[],
                            args=(
                                [self.sync(ast3.arg(arg="self", annotation=None))]
                                if node.is_method
                                else []
                            ),
                            vararg=None,
                            kwonlyargs=[],
                            kw_defaults=[],
                            kwarg=None,
                            defaults=[],
                        )
                    )
                ),
                body=[cast(ast3.stmt, i) for i in body],
                decorator_list=[cast(ast3.expr, i) for i in decorator_list],
                returns=ast_returns,
                type_params=[],
            )
        )
        node.gen.py_ast = [func_def]

    def exit_impl_def(self, node: uni.ImplDef) -> None:
        pass

    def exit_sem_def(self, node: uni.SemDef) -> None:
        pass

    def exit_func_signature(self, node: uni.FuncSignature) -> None:
        posonlyargs = [i.gen.py_ast[0] for i in node.posonly_params]
        vararg = node.varargs.gen.py_ast[0] if node.varargs else None
        kwarg = node.kwargs.gen.py_ast[0] if node.kwargs else None
        params = (
            [self.sync(ast3.arg(arg="self", annotation=None))]
            if (abl := node.parent)
            and isinstance(abl, uni.Ability)
            and abl.is_method
            and not node.is_static
            and not node.is_in_py_class
            else []
        )
        if posonlyargs:
            posonlyargs = params + posonlyargs
            params = [cast(ast3.arg, i.gen.py_ast[0]) for i in node.params]
        else:
            params = params + [cast(ast3.arg, i.gen.py_ast[0]) for i in node.params]
        defaults = []
        for i in [*node.posonly_params, *node.params]:
            if i.value:
                defaults.append(cast(ast3.expr, i.value.gen.py_ast[0]))
        kwonly_args = [cast(ast3.arg, i.gen.py_ast[0]) for i in node.kwonlyargs]
        # kw_defaults must be the same length as kwonlyargs
        # it will have None for args that don't have defaults
        kw_defaults: list[ast3.expr | None] = []
        for i in node.kwonlyargs:
            if i.value:
                kw_defaults.append(cast(ast3.expr, i.value.gen.py_ast[0]))
            else:
                kw_defaults.append(None)
        node.gen.py_ast = [
            self.sync(
                ast3.arguments(
                    posonlyargs=[cast(ast3.arg, param) for param in posonlyargs],
                    args=[cast(ast3.arg, param) for param in params],
                    kwonlyargs=kwonly_args,
                    vararg=cast(ast3.arg, vararg) if vararg else None,
                    kwarg=cast(ast3.arg, kwarg) if kwarg else None,
                    kw_defaults=kw_defaults,
                    defaults=[cast(ast3.expr, default) for default in defaults],
                )
            )
        ]

    def exit_event_signature(self, node: uni.EventSignature) -> None:
        arch_kw = Con.HERE.value if node.from_walker else Con.VISITOR.value

        # Convert annotation: if it's a TupleVal, convert to Union type (X | Y)
        annotation = None
        if node.arch_tag_info:
            py_ast = cast(ast3.expr, node.arch_tag_info.gen.py_ast[0])
            # Check if the annotation is a tuple (from `with (Book, Magazine) entry`)
            # If so, convert to Union type using bitwise OR operator (Book | Magazine)
            if isinstance(py_ast, ast3.Tuple) and isinstance(
                node.arch_tag_info, uni.TupleVal
            ):
                # Convert tuple to union type: (A, B, C) -> A | B | C
                if len(py_ast.elts) > 1:
                    # Build union by chaining BinOp with BitOr
                    annotation = py_ast.elts[0]
                    for elem in py_ast.elts[1:]:
                        annotation = self.sync(
                            ast3.BinOp(
                                left=annotation,
                                op=self.sync(ast3.BitOr()),
                                right=elem,
                            )
                        )
                elif len(py_ast.elts) == 1:
                    # Single element tuple, just use the element
                    annotation = py_ast.elts[0]
            else:
                annotation = py_ast

        arch_arg = self.sync(
            ast3.arg(
                arg=f"{arch_kw}",
                annotation=annotation,
            ),
            jac_node=node.arch_tag_info if node.arch_tag_info else node,
        )
        node.gen.py_ast = [
            self.sync(
                ast3.arguments(
                    posonlyargs=[],
                    args=(
                        [self.sync(ast3.arg(arg="self", annotation=None)), arch_arg]
                        if (abl := node.find_parent_of_type(uni.Ability))
                        and abl.is_method
                        else [arch_arg]
                    ),
                    kwonlyargs=[],
                    vararg=None,
                    kwarg=None,
                    kw_defaults=[],
                    defaults=[],
                )
            )
        ]

    def exit_type_ref(self, node: uni.TypeRef) -> None:
        if (
            isinstance(node.target, uni.SpecialVarRef)
            and node.target.orig.name == Tok.KW_ROOT
        ):
            node.gen.py_ast = [self.jaclib_obj("Root")]
        else:
            self.needs_typing()
            node.gen.py_ast = [
                self.sync(
                    ast3.Attribute(
                        value=self.sync(ast3.Name(id="typing", ctx=ast3.Load())),
                        attr=node.target.sym_name,
                        ctx=ast3.Load(),
                    )
                )
            ]

    def exit_param_var(self, node: uni.ParamVar) -> None:
        if isinstance(node.name.gen.py_ast[0], ast3.Name):
            name = node.name.gen.py_ast[0].id
            node.gen.py_ast = [
                self.sync(
                    ast3.arg(
                        arg=name,
                        annotation=(
                            cast(ast3.expr, node.type_tag.gen.py_ast[0])
                            if node.type_tag
                            else None
                        ),
                    )
                )
            ]

    def exit_arch_has(self, node: uni.ArchHas) -> None:
        vars_py: list[ast3.AST] = self._flatten_ast_list(
            [v.gen.py_ast for v in node.vars]
        )
        if node.doc:
            doc = self.sync(
                ast3.Expr(value=cast(ast3.expr, node.doc.gen.py_ast[0])),
                jac_node=node.doc,
            )
            if isinstance(doc, ast3.AST):
                node.gen.py_ast = [doc] + vars_py
            else:
                raise self.ice()
        else:
            node.gen.py_ast = vars_py

    def exit_has_var(self, node: uni.HasVar) -> None:
        annotation = node.type_tag.gen.py_ast[0] if node.type_tag else None

        is_static_var = (
            (haspar := node.find_parent_of_type(uni.ArchHas))
            and haspar
            and haspar.is_static
        )
        is_in_class = (
            (archpar := node.find_parent_of_type(uni.Archetype))
            and archpar
            and archpar.arch_type.name == Tok.KW_CLASS
        )

        value = None

        if is_in_class:
            value = cast(ast3.expr, node.value.gen.py_ast[0]) if node.value else None
        elif is_static_var:
            annotation = self.sync(
                ast3.Subscript(
                    value=self.builtin_name("ClassVar"),
                    slice=cast(ast3.expr, annotation),
                    ctx=ast3.Load(),
                )
            )
            value = cast(ast3.expr, node.value.gen.py_ast[0]) if node.value else None
        elif node.defer:
            value = self.sync(
                ast3.Call(
                    func=self.jaclib_obj("field"),
                    args=[],
                    keywords=[
                        self.sync(
                            ast3.keyword(
                                arg="init",
                                value=self.sync(ast3.Constant(value=False)),
                            )
                        )
                    ],
                ),
            )
        elif node.value:
            if isinstance(node.value.gen.py_ast[0], ast3.Constant):
                value = cast(ast3.expr, node.value.gen.py_ast[0])
            else:
                value = self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("field"),
                        args=[],
                        keywords=[
                            self.sync(
                                ast3.keyword(
                                    arg="factory",
                                    value=self.sync(
                                        ast3.Lambda(
                                            args=self.sync(
                                                ast3.arguments(
                                                    posonlyargs=[],
                                                    args=[],
                                                    kwonlyargs=[],
                                                    vararg=None,
                                                    kwarg=None,
                                                    kw_defaults=[],
                                                    defaults=[],
                                                )
                                            ),
                                            body=cast(
                                                ast3.expr,
                                                node.value.gen.py_ast[0],
                                            ),
                                        )
                                    ),
                                ),
                            )
                        ],
                    ),
                )

        node.gen.py_ast = [
            self.sync(
                ast3.AnnAssign(
                    target=cast(
                        ast3.Name | ast3.Attribute | ast3.Subscript,
                        node.name.gen.py_ast[0],
                    ),
                    annotation=(
                        cast(ast3.expr, annotation)
                        if annotation
                        else ast3.Constant(value=None)
                    ),
                    value=value,
                    simple=int(isinstance(node.name, uni.Name)),
                )
            )
        ]

    def exit_typed_ctx_block(self, node: uni.TypedCtxBlock) -> None:
        loc = self.sync(
            ast3.Name(id=Con.HERE.value, ctx=ast3.Load())
            if node.from_walker
            else ast3.Name(id=Con.VISITOR.value, ctx=ast3.Load())
        )
        node.gen.py_ast = [
            self.sync(
                ast3.If(
                    test=self.sync(
                        ast3.Call(
                            func=self.sync(ast3.Name(id="isinstance", ctx=ast3.Load())),
                            args=[
                                loc,
                                cast(ast3.expr, node.type_ctx.gen.py_ast[0]),
                            ],
                            keywords=[],
                        )
                    ),
                    body=cast(list[ast3.stmt], self.resolve_stmt_block(node.body)),
                    orelse=[],
                )
            )
        ]

    def exit_if_stmt(self, node: uni.IfStmt) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.If(
                    test=cast(ast3.expr, node.condition.gen.py_ast[0]),
                    body=cast(list[ast3.stmt], self.resolve_stmt_block(node.body)),
                    orelse=(
                        cast(list[ast3.stmt], node.else_body.gen.py_ast)
                        if node.else_body
                        else []
                    ),
                )
            )
        ]

    def exit_else_if(self, node: uni.ElseIf) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.If(
                    test=cast(ast3.expr, node.condition.gen.py_ast[0]),
                    body=cast(list[ast3.stmt], self.resolve_stmt_block(node.body)),
                    orelse=(
                        cast(list[ast3.stmt], node.else_body.gen.py_ast)
                        if node.else_body
                        else []
                    ),
                )
            )
        ]

    def exit_else_stmt(self, node: uni.ElseStmt) -> None:
        node.gen.py_ast = self.resolve_stmt_block(node.body)

    def exit_expr_stmt(self, node: uni.ExprStmt) -> None:
        # Collect any hoisted functions that were generated during expression evaluation
        hoisted = self._hoisted_funcs[:]
        self._hoisted_funcs.clear()

        expr_stmt = (
            self.sync(ast3.Expr(value=cast(ast3.expr, node.expr.gen.py_ast[0])))
            if not node.in_fstring
            else self.sync(
                ast3.FormattedValue(
                    value=cast(ast3.expr, node.expr.gen.py_ast[0]),
                    conversion=-1,
                    format_spec=None,
                )
            )
        )

        # Emit hoisted functions before the expression statement
        node.gen.py_ast = [*hoisted, expr_stmt]

    def exit_concurrent_expr(self, node: uni.ConcurrentExpr) -> None:
        func = ""
        if node.tok:
            match node.tok.value:
                case "flow":
                    func = "thread_run"
                case "wait":
                    func = "thread_wait"
        if func:
            lambda_ex = [
                self.sync(
                    ast3.Lambda(
                        args=(
                            self.sync(
                                ast3.arguments(
                                    posonlyargs=[],
                                    args=[],
                                    kwonlyargs=[],
                                    kw_defaults=[],
                                    defaults=[],
                                )
                            )
                        ),
                        body=cast(ast3.expr, node.target.gen.py_ast[0]),
                    )
                )
            ]
            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj(func),
                        args=cast(
                            list[ast3.expr],
                            (
                                lambda_ex
                                if func == "thread_run"
                                else [node.target.gen.py_ast[0]]  # type: ignore
                            ),
                        ),
                        keywords=[],
                    )
                )
            ]

    def exit_try_stmt(self, node: uni.TryStmt) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.Try(
                    body=cast(list[ast3.stmt], self.resolve_stmt_block(node.body)),
                    handlers=[
                        cast(ast3.ExceptHandler, i.gen.py_ast[0]) for i in node.excepts
                    ],
                    orelse=(
                        [cast(ast3.stmt, i) for i in node.else_body.gen.py_ast]
                        if node.else_body
                        else []
                    ),
                    finalbody=(
                        [cast(ast3.stmt, i) for i in node.finally_body.gen.py_ast]
                        if node.finally_body
                        else []
                    ),
                )
            )
        ]

    def exit_except(self, node: uni.Except) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.ExceptHandler(
                    type=(
                        cast(ast3.expr, node.ex_type.gen.py_ast[0])
                        if node.ex_type
                        else None
                    ),
                    name=node.name.sym_name if node.name else None,
                    body=[
                        cast(ast3.stmt, stmt)
                        for stmt in self.resolve_stmt_block(node.body)
                    ],
                )
            )
        ]

    def exit_finally_stmt(self, node: uni.FinallyStmt) -> None:
        node.gen.py_ast = self.resolve_stmt_block(node.body)

    def exit_iter_for_stmt(self, node: uni.IterForStmt) -> None:
        py_nodes: list[ast3.AST] = []
        body = self.resolve_stmt_block(node.body)
        if (
            isinstance(body, list)
            and isinstance(node.count_by.gen.py_ast[0], ast3.AST)
            and isinstance(node.iter.gen.py_ast[0], ast3.AST)
        ):
            body += [node.count_by.gen.py_ast[0]]
        else:
            raise self.ice()
        py_nodes.append(node.iter.gen.py_ast[0])
        py_nodes.append(
            self.sync(
                ast3.While(
                    test=cast(ast3.expr, node.condition.gen.py_ast[0]),
                    body=[cast(ast3.stmt, stmt) for stmt in body],
                    orelse=(
                        [cast(ast3.stmt, stmt) for stmt in node.else_body.gen.py_ast]
                        if node.else_body
                        else []
                    ),
                )
            )
        )
        node.gen.py_ast = py_nodes

    def exit_in_for_stmt(self, node: uni.InForStmt) -> None:
        for_node = ast3.AsyncFor if node.is_async else ast3.For
        node.gen.py_ast = [
            self.sync(
                for_node(
                    target=cast(ast3.expr, node.target.gen.py_ast[0]),
                    iter=cast(ast3.expr, node.collection.gen.py_ast[0]),
                    body=[
                        cast(ast3.stmt, stmt)
                        for stmt in self.resolve_stmt_block(node.body)
                    ],
                    orelse=(
                        [cast(ast3.stmt, stmt) for stmt in node.else_body.gen.py_ast]
                        if node.else_body
                        else []
                    ),
                )
            )
        ]

    def exit_while_stmt(self, node: uni.WhileStmt) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.While(
                    test=cast(ast3.expr, node.condition.gen.py_ast[0]),
                    body=[
                        cast(ast3.stmt, stmt)
                        for stmt in self.resolve_stmt_block(node.body)
                    ],
                    orelse=(
                        [cast(ast3.stmt, stmt) for stmt in node.else_body.gen.py_ast]
                        if node.else_body
                        else []
                    ),
                )
            )
        ]

    def exit_with_stmt(self, node: uni.WithStmt) -> None:
        with_node = ast3.AsyncWith if node.is_async else ast3.With
        node.gen.py_ast = [
            self.sync(
                with_node(
                    items=[
                        cast(ast3.withitem, item.gen.py_ast[0]) for item in node.exprs
                    ],
                    body=[
                        cast(ast3.stmt, stmt)
                        for stmt in self.resolve_stmt_block(node.body)
                    ],
                )
            )
        ]

    def exit_expr_as_item(self, node: uni.ExprAsItem) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.withitem(
                    context_expr=cast(ast3.expr, node.expr.gen.py_ast[0]),
                    optional_vars=(
                        cast(ast3.expr, node.alias.gen.py_ast[0])
                        if node.alias
                        else None
                    ),
                )
            )
        ]

    def exit_raise_stmt(self, node: uni.RaiseStmt) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.Raise(
                    exc=(
                        cast(ast3.expr, node.cause.gen.py_ast[0])
                        if node.cause
                        else None
                    ),
                    cause=(
                        cast(ast3.expr, node.from_target.gen.py_ast[0])
                        if node.from_target
                        else None
                    ),
                )
            )
        ]

    def exit_assert_stmt(self, node: uni.AssertStmt) -> None:
        if isinstance(node.parent, uni.Test):
            self.assert_helper(node)
        else:
            node.gen.py_ast = [
                self.sync(
                    ast3.Assert(
                        test=cast(ast3.expr, node.condition.gen.py_ast[0]),
                        msg=(
                            cast(ast3.expr, node.error_msg.gen.py_ast[0])
                            if node.error_msg
                            else None
                        ),
                    )
                )
            ]

    def assert_helper(self, node: uni.AssertStmt) -> None:
        """Sub objects.

        target: ExprType,
        """
        # TODO: Here is the list of assertions which are not implemented instead a simpler version of them will work.
        # ie. [] == [] will be assertEqual instead of assertListEqual. However I don't think this is needed since it can
        # only detected if both operand are compile time literal list or type inferable.
        #
        #   assertAlmostEqual
        #   assertNotAlmostEqual
        #   assertSequenceEqual
        #   assertListEqual
        #   assertTupleEqual
        #   assertSetEqual
        #   assertDictEqual
        #   assertCountEqual
        #   assertMultiLineEqual
        #   assertRaisesRegex
        #   assertWarnsRegex
        #   assertRegex
        #   assertNotRegex

        # The return type "struct" for the bellow check_node_isinstance_call.
        @dataclass
        class CheckNodeIsinstanceCallResult:
            isit: bool = False
            inst: ast3.AST | None = None
            clss: ast3.AST | None = None

        # This will check if a node is `isinstance(<expr>, <expr>)`, we're
        # using a function because it's reusable to check not isinstance(<expr>, <expr>).
        def check_node_isinstance_call(
            node: uni.FuncCall,
        ) -> CheckNodeIsinstanceCallResult:
            # Ensure the func call has exactly two expression parameters
            if not (
                len(node.params) == 2
                and isinstance(node.params[0], uni.Expr)
                and isinstance(node.params[1], uni.Expr)
            ):
                return CheckNodeIsinstanceCallResult()

            func = node.target.gen.py_ast[0]
            if not (isinstance(func, ast3.Name) and func.id == "isinstance"):
                return CheckNodeIsinstanceCallResult()

            return CheckNodeIsinstanceCallResult(
                True,
                node.params[0].gen.py_ast[0],
                node.params[1].gen.py_ast[0],
            )

        # By default the check expression will become assertTrue(<expr>), unless any pattern detected.
        assert_func_name = "assertTrue"
        assert_args_list = node.condition.gen.py_ast

        # Compare operations. Note that We're only considering the compare
        # operation with a single operation ie. a < b < c is  ignored here.
        if (
            isinstance(node.condition, uni.CompareExpr)
            and isinstance(node.condition.gen.py_ast[0], ast3.Compare)
            and len(node.condition.ops) == 1
        ):
            expr: uni.CompareExpr = node.condition
            opty: uni.Token = expr.ops[0]

            optype2fn = {
                Tok.EE.name: "assertEqual",
                Tok.NE.name: "assertNotEqual",
                Tok.LT.name: "assertLess",
                Tok.LTE.name: "assertLessEqual",
                Tok.GT.name: "assertGreater",
                Tok.GTE.name: "assertGreaterEqual",
                Tok.KW_IN.name: "assertIn",
                Tok.KW_NIN.name: "assertNotIn",
                Tok.KW_IS.name: "assertIs",
                Tok.KW_ISN.name: "assertIsNot",
            }

            if opty.name in optype2fn:
                assert_func_name = optype2fn[opty.name]
                assert_args_list = [
                    expr.left.gen.py_ast[0],
                    expr.rights[0].gen.py_ast[0],
                ]

                # Override for <expr> is None.
                if opty.name == Tok.KW_IS and isinstance(expr.rights[0], uni.Null):
                    assert_func_name = "assertIsNone"
                    assert_args_list.pop()

                # Override for <expr> is not None.
                elif opty.name == Tok.KW_ISN and isinstance(expr.rights[0], uni.Null):
                    assert_func_name = "assertIsNotNone"
                    assert_args_list.pop()

        # Check if 'isinstance' is called.
        elif isinstance(node.condition, uni.FuncCall) and isinstance(
            node.condition.gen.py_ast[0], ast3.Call
        ):
            res = check_node_isinstance_call(node.condition)
            if res.isit:
                # These assertions will make mypy happy.
                assert isinstance(res.inst, ast3.AST)
                assert isinstance(res.clss, ast3.AST)
                assert_func_name = "assertIsInstance"
                assert_args_list = [res.inst, res.clss]

        # Check if 'not isinstance(<expr>, <expr>)' is called.
        elif (
            isinstance(node.condition, uni.UnaryExpr)
            and isinstance(node.condition, uni.UnaryExpr)
            and isinstance(node.condition.operand, uni.FuncCall)
            and isinstance(node.condition.operand, uni.UnaryExpr)
        ):
            res = check_node_isinstance_call(node.condition.operand)
            if res.isit:
                # These assertions will make mypy happy.
                assert isinstance(res.inst, ast3.AST)
                assert isinstance(res.clss, ast3.AST)
                assert_func_name = "assertIsNotInstance"
                assert_args_list = [res.inst, res.clss]

        # NOTE That the almost equal is NOT a builtin function of jaclang and won't work outside of the
        # check statement. And we're hacking the node here. Not sure if this is a hacky workaround to support
        # the almost equal functionality (snice there is no almost equal operator in jac and never needed ig.).

        # Check if 'almostEqual' is called.
        if isinstance(node.condition, uni.FuncCall) and isinstance(
            node.condition.gen.py_ast[0], ast3.Call
        ):
            func = node.condition.target
            if isinstance(func, uni.Name) and func.value == "almostEqual":
                assert_func_name = "assertAlmostEqual"
                assert_args_list = []
                for param in node.condition.params:
                    assert_args_list.append(param.gen.py_ast[0])

        # assert_func_expr = "Con.JAC_CHECK.value.assertXXX"
        assert_func_expr: ast3.Attribute = self.sync(
            ast3.Attribute(
                value=self.sync(ast3.Name(id=Con.JAC_CHECK.value, ctx=ast3.Load())),
                attr=assert_func_name,
                ctx=ast3.Load(),
            )
        )

        # assert_call_expr = "(Con.JAC_CHECK.value.assertXXX)(args)"
        assert_call_expr: ast3.Call = self.sync(
            ast3.Call(
                func=assert_func_expr,
                args=[cast(ast3.expr, arg) for arg in assert_args_list],
                keywords=[],
            )
        )

        node.gen.py_ast = [self.sync(ast3.Expr(assert_call_expr))]

    def exit_ctrl_stmt(self, node: uni.CtrlStmt) -> None:
        if node.ctrl.name == Tok.KW_BREAK:
            node.gen.py_ast = [self.sync(ast3.Break())]
        elif node.ctrl.name == Tok.KW_CONTINUE:
            if iter_for_parent := self.find_parent_of_type(node, uni.IterForStmt):
                count_by = iter_for_parent.count_by
                node.gen.py_ast = [count_by.gen.py_ast[0], self.sync(ast3.Continue())]
            else:
                node.gen.py_ast = [self.sync(ast3.Continue())]
        elif node.ctrl.name == Tok.KW_SKIP:
            node.gen.py_ast = [self.sync(ast3.Return(value=None))]

    def exit_delete_stmt(self, node: uni.DeleteStmt) -> None:
        def set_ctx(targets: ast3.AST | list[ast3.AST], ctx: type) -> list[ast3.AST]:
            """Set the given ctx (Load, Del) to AST node(s)."""
            if not isinstance(targets, list):
                targets = [targets]
            elif isinstance(targets[0], (ast3.List, ast3.Tuple)):
                targets = [i for i in targets[0].elts if isinstance(i, ast3.AST)]
            result = []
            for target in targets:
                if hasattr(target, "ctx"):
                    target = copy.copy(target)
                    target.ctx = ctx()
                result.append(target)
            return result

        destroy_expr = ast3.Expr(
            value=self.sync(
                ast3.Call(
                    func=self.jaclib_obj("destroy"),
                    args=[
                        self.sync(
                            ast3.List(
                                elts=cast(
                                    list[ast3.expr],
                                    set_ctx(node.py_ast_targets, ast3.Load),
                                ),
                                ctx=ast3.Load(),
                            )
                        )
                    ],
                    keywords=[],
                )
            )
        )
        delete_stmt = self.sync(
            ast3.Delete(
                targets=cast(list[ast3.expr], set_ctx(node.py_ast_targets, ast3.Del))
            )
        )
        node.gen.py_ast = [self.sync(destroy_expr), self.sync(delete_stmt)]

    def exit_report_stmt(self, node: uni.ReportStmt) -> None:
        if isinstance(node.expr, uni.YieldExpr):
            fun_name = "log_report_yield"
        else:
            fun_name = "log_report"
        node.gen.py_ast = [
            self.sync(
                ast3.Expr(
                    value=self.sync(
                        self.sync(
                            ast3.Call(
                                func=self.jaclib_obj(fun_name),
                                args=cast(list[ast3.expr], node.expr.gen.py_ast),
                                keywords=[],
                            )
                        )
                    )
                )
            )
        ]

    def exit_return_stmt(self, node: uni.ReturnStmt) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.Return(
                    value=(
                        cast(ast3.expr, node.expr.gen.py_ast[0]) if node.expr else None
                    )
                )
            )
        ]

    def exit_yield_expr(self, node: uni.YieldExpr) -> None:
        if not node.with_from:
            node.gen.py_ast = [
                self.sync(
                    ast3.Yield(
                        value=(
                            cast(ast3.expr, node.expr.gen.py_ast[0])
                            if node.expr
                            else None
                        )
                    )
                )
            ]
        else:
            node.gen.py_ast = [
                self.sync(
                    ast3.YieldFrom(
                        value=(
                            cast(ast3.expr, node.expr.gen.py_ast[0])
                            if node.expr
                            else self.sync(ast3.Constant(value=None))
                        )
                    )
                )
            ]

    def exit_visit_stmt(self, node: uni.VisitStmt) -> None:
        loc = self.sync(
            ast3.Name(id="self", ctx=ast3.Load())
            if node.from_walker
            else ast3.Name(id=Con.VISITOR.value, ctx=ast3.Load())
        )

        visit_call = self.sync(
            ast3.Call(
                func=self.jaclib_obj("visit"),
                args=cast(list[ast3.expr], [loc, node.target.gen.py_ast[0]]),
                keywords=[],
            )
        )

        if node.insert_loc is not None:
            visit_call.keywords.append(
                self.sync(
                    ast3.keyword(
                        arg="insert_loc",
                        value=cast(ast3.expr, node.insert_loc.gen.py_ast[0]),
                    )
                )
            )

        node.gen.py_ast = [
            (
                self.sync(
                    ast3.If(
                        test=self.sync(
                            ast3.UnaryOp(
                                op=self.sync(ast3.Not()),
                                operand=visit_call,
                            )
                        ),
                        body=cast(list[ast3.stmt], node.else_body.gen.py_ast),
                        orelse=[],
                    )
                )
                if node.else_body
                else self.sync(ast3.Expr(value=visit_call))
            )
        ]

    def exit_disengage_stmt(self, node: uni.DisengageStmt) -> None:
        loc = self.sync(
            ast3.Name(id="self", ctx=ast3.Load())
            if node.from_walker
            else ast3.Name(id=Con.VISITOR.value, ctx=ast3.Load())
        )
        node.gen.py_ast = [
            self.sync(
                ast3.Expr(
                    self.sync(
                        ast3.Call(
                            func=self.jaclib_obj("disengage"),
                            args=[loc],
                            keywords=[],
                        )
                    )
                )
            ),
            self.sync(ast3.Return()),
        ]

    def exit_await_expr(self, node: uni.AwaitExpr) -> None:
        node.gen.py_ast = [
            self.sync(ast3.Await(value=cast(ast3.expr, node.target.gen.py_ast[0])))
        ]

    def exit_global_stmt(self, node: uni.GlobalStmt) -> None:
        py_nodes = []
        for x in node.target:
            py_nodes.append(
                self.sync(
                    ast3.Global(names=[x.sym_name]),
                    jac_node=x,
                )
            )
        node.gen.py_ast = [*py_nodes]

    def exit_non_local_stmt(self, node: uni.NonLocalStmt) -> None:
        py_nodes = []
        for x in node.target:
            py_nodes.append(
                self.sync(
                    ast3.Nonlocal(names=[x.sym_name]),
                    jac_node=x,
                )
            )
        node.gen.py_ast = [*py_nodes]

    def exit_assignment(self, node: uni.Assignment) -> None:
        value = (
            node.value.gen.py_ast[0]
            if node.value
            else (
                self.sync(
                    ast3.Call(
                        func=self.sync(ast3.Name(id="auto", ctx=ast3.Load())),
                        args=[],
                        keywords=[],
                    )
                )
                if node.is_enum_stmt
                else None
                if node.type_tag
                else self.ice()
            )
        )
        targets_ast = [cast(ast3.expr, t.gen.py_ast[0]) for t in node.target]

        # Collect any hoisted functions that were generated during expression evaluation
        hoisted = self._hoisted_funcs[:]
        self._hoisted_funcs.clear()

        if node.type_tag:
            assignment_stmt: ast3.AnnAssign | ast3.Assign | ast3.AugAssign = self.sync(
                ast3.AnnAssign(
                    target=cast(ast3.Name, targets_ast[0]),
                    annotation=cast(ast3.expr, node.type_tag.gen.py_ast[0]),
                    value=(
                        cast(ast3.expr, node.value.gen.py_ast[0])
                        if node.value
                        else None
                    ),
                    simple=int(isinstance(targets_ast[0], ast3.Name)),
                )
            )
        elif node.aug_op:
            assignment_stmt = self.sync(
                ast3.AugAssign(
                    target=cast(ast3.Name, targets_ast[0]),
                    op=cast(ast3.operator, node.aug_op.gen.py_ast[0]),
                    value=(
                        cast(ast3.expr, value)
                        if isinstance(value, ast3.expr)
                        else ast3.Constant(value=None)
                    ),
                )
            )
        else:
            assignment_stmt = self.sync(
                ast3.Assign(
                    targets=cast(list[ast3.expr], targets_ast),
                    value=(
                        cast(ast3.expr, value)
                        if isinstance(value, ast3.expr)
                        else ast3.Constant(value=None)
                    ),
                )
            )

        # Emit hoisted functions before the assignment
        node.gen.py_ast = [*hoisted, assignment_stmt]

    def exit_binary_expr(self, node: uni.BinaryExpr) -> None:
        if isinstance(node.op, uni.ConnectOp):
            left = (
                node.right.gen.py_ast[0]
                if node.op.edge_dir == EdgeDir.IN
                else node.left.gen.py_ast[0]
            )
            right = (
                node.left.gen.py_ast[0]
                if node.op.edge_dir == EdgeDir.IN
                else node.right.gen.py_ast[0]
            )

            keywords = [
                self.sync(ast3.keyword(arg="left", value=cast(ast3.expr, left))),
                self.sync(ast3.keyword(arg="right", value=cast(ast3.expr, right))),
            ]

            if node.op.conn_type:
                keywords.append(
                    self.sync(
                        ast3.keyword(
                            arg="edge",
                            value=cast(ast3.expr, node.op.conn_type.gen.py_ast[0]),
                        )
                    )
                )

            if node.op.edge_dir == EdgeDir.ANY:
                keywords.append(
                    self.sync(
                        ast3.keyword(
                            arg="undir", value=self.sync(ast3.Constant(value=True))
                        )
                    )
                )

            if node.op.conn_assign:
                keywords.append(
                    self.sync(
                        ast3.keyword(
                            arg="conn_assign",
                            value=cast(ast3.expr, node.op.conn_assign.gen.py_ast[0]),
                        )
                    )
                )

            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("connect"),
                        args=[],
                        keywords=keywords,
                    )
                )
            ]

        elif isinstance(node.op, uni.DisconnectOp):
            keywords = [
                self.sync(
                    ast3.keyword(
                        arg="left", value=cast(ast3.expr, node.left.gen.py_ast[0])
                    )
                ),
                self.sync(
                    ast3.keyword(
                        arg="right", value=cast(ast3.expr, node.right.gen.py_ast[0])
                    )
                ),
            ]

            if node.op.edge_spec.edge_dir != EdgeDir.OUT:
                keywords.append(
                    self.sync(
                        ast3.keyword(
                            arg="EdgeDir",
                            value=self.sync(
                                ast3.Attribute(
                                    value=self.jaclib_obj("EdgeDir"),
                                    attr=node.op.edge_spec.edge_dir.name,
                                    ctx=ast3.Load(),
                                )
                            ),
                        )
                    )
                )

            if node.op.edge_spec.filter_cond:
                keywords.append(
                    self.sync(
                        ast3.keyword(
                            arg="filter_on",
                            value=cast(
                                ast3.expr,
                                node.op.edge_spec.filter_cond.gen.py_ast[0],
                            ),
                        ),
                    )
                )

            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("disconnect"),
                        args=[],
                        keywords=keywords,
                    )
                )
            ]
        elif node.op.name in [Tok.KW_AND.value, Tok.KW_OR.value]:
            node.gen.py_ast = [
                self.sync(
                    ast3.BoolOp(
                        op=cast(ast3.boolop, node.op.gen.py_ast[0]),
                        values=[
                            cast(ast3.expr, node.left.gen.py_ast[0]),
                            cast(ast3.expr, node.right.gen.py_ast[0]),
                        ],
                    )
                )
            ]
        elif node.op.name in [Tok.WALRUS_EQ] and isinstance(
            node.left.gen.py_ast[0], ast3.Name
        ):
            node.left.gen.py_ast[0].ctx = ast3.Store()  # TODO: Short term fix
            node.gen.py_ast = [
                self.sync(
                    ast3.NamedExpr(
                        target=cast(ast3.Name, node.left.gen.py_ast[0]),
                        value=cast(ast3.expr, node.right.gen.py_ast[0]),
                    )
                )
            ]
        elif node.op.gen.py_ast and isinstance(node.op.gen.py_ast[0], ast3.AST):
            node.gen.py_ast = [
                self.sync(
                    ast3.BinOp(
                        left=cast(ast3.expr, node.left.gen.py_ast[0]),
                        right=cast(ast3.expr, node.right.gen.py_ast[0]),
                        op=cast(ast3.operator, node.op.gen.py_ast[0]),
                    )
                )
            ]
        else:
            node.gen.py_ast = self.translate_jac_bin_op(node)

    def translate_jac_bin_op(self, node: uni.BinaryExpr) -> list[ast3.AST]:
        if isinstance(node.op, (uni.DisconnectOp, uni.ConnectOp)):
            raise self.ice()
        elif node.op.name in [
            Tok.PIPE_FWD,
            Tok.A_PIPE_FWD,
        ]:
            func_node = uni.FuncCall(
                target=node.right,
                params=(
                    list(node.left.values)
                    if isinstance(node.left, uni.TupleVal) and node.left.values
                    else [node.left]
                ),
                genai_call=None,
                kid=node.kid,
            )
            func_node.parent = node.parent
            self.exit_func_call(func_node)
            return func_node.gen.py_ast
        elif node.op.name in [Tok.KW_SPAWN]:
            return [
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("spawn"),
                        args=cast(
                            list[ast3.expr],
                            [node.left.gen.py_ast[0], node.right.gen.py_ast[0]],
                        ),
                        keywords=[],
                    )
                )
            ]
        elif node.op.name in [
            Tok.PIPE_BKWD,
            Tok.A_PIPE_BKWD,
        ]:
            func_node = uni.FuncCall(
                target=node.left,
                params=(
                    list(node.right.values)
                    if isinstance(node.right, uni.TupleVal) and node.right.values
                    else [node.right]
                ),
                genai_call=None,
                kid=node.kid,
            )
            func_node.parent = node.parent
            self.exit_func_call(func_node)
            return func_node.gen.py_ast
        elif node.op.name in [Tok.KW_BY]:
            return [
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("by_operator"),
                        args=cast(
                            list[ast3.expr],
                            [node.left.gen.py_ast[0], node.right.gen.py_ast[0]],
                        ),
                        keywords=[],
                    )
                )
            ]
        elif node.op.name == Tok.PIPE_FWD and isinstance(node.right, uni.TupleVal):
            self.log_error("Invalid pipe target.")
        else:
            self.log_error(
                f"Binary operator {node.op.value} not supported in bootstrap Jac"
            )
        return []

    def exit_compare_expr(self, node: uni.CompareExpr) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.Compare(
                    left=cast(ast3.expr, node.left.gen.py_ast[0]),
                    comparators=[cast(ast3.expr, i.gen.py_ast[0]) for i in node.rights],
                    ops=[cast(ast3.cmpop, i.gen.py_ast[0]) for i in node.ops],
                )
            )
        ]

    def exit_bool_expr(self, node: uni.BoolExpr) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.BoolOp(
                    op=cast(ast3.boolop, node.op.gen.py_ast[0]),
                    values=[cast(ast3.expr, i.gen.py_ast[0]) for i in node.values],
                )
            )
        ]

    def exit_lambda_expr(self, node: uni.LambdaExpr) -> None:
        # Multi-statement lambda emits a synthesized function definition that is
        # hoisted before the current statement.
        if isinstance(node.body, list):
            if node.signature and node.signature.gen.py_ast:
                arguments = cast(ast3.arguments, node.signature.gen.py_ast[0])
            else:
                arguments = self.sync(
                    ast3.arguments(
                        posonlyargs=[],
                        args=[],
                        kwonlyargs=[],
                        kw_defaults=[],
                        defaults=[],
                    ),
                    jac_node=node,
                )
            body_stmts = [
                cast(ast3.stmt, stmt)
                for stmt in self.resolve_stmt_block(node.body, doc=None)
            ]
            if not body_stmts:
                body_stmts = [self.sync(ast3.Pass(), jac_node=node)]
            func_name = self._next_temp_name("lambda")
            returns = (
                cast(ast3.expr, node.signature.return_type.gen.py_ast[0])
                if node.signature
                and node.signature.return_type
                and node.signature.return_type.gen.py_ast
                else None
            )
            func_def = self.sync(
                ast3.FunctionDef(
                    name=func_name,
                    args=arguments,
                    body=body_stmts,
                    decorator_list=[],
                    returns=returns,
                    type_params=[],
                ),
                jac_node=node,
            )
            node.gen.py_ast = [
                self._function_expr_from_def(
                    func_def=func_def,
                    jac_node=node,
                    filename_hint=f"<jac_lambda:{func_name}>",
                )
            ]
            return

        # Single-expression lambda maps directly to Python lambda; strip annotations.
        if node.signature:
            self._remove_lambda_param_annotations(node.signature)
        if node.signature and node.signature.gen.py_ast:
            arguments = cast(ast3.arguments, node.signature.gen.py_ast[0])
        else:
            arguments = self.sync(
                ast3.arguments(
                    posonlyargs=[],
                    args=[],
                    kwonlyargs=[],
                    kw_defaults=[],
                    defaults=[],
                ),
                jac_node=node,
            )
        # At this point node.body is guaranteed to be an Expr (list case returned above)
        body_node = cast(uni.Expr, node.body)
        body_expr = cast(ast3.expr, body_node.gen.py_ast[0])
        node.gen.py_ast = [
            self.sync(
                ast3.Lambda(
                    args=arguments,
                    body=body_expr,
                ),
                jac_node=node,
            )
        ]

    def _remove_lambda_param_annotations(self, signature: uni.FuncSignature) -> None:
        for param in signature.params:
            if param.gen.py_ast and isinstance(param.gen.py_ast[0], ast3.arg):
                param.gen.py_ast[0].annotation = None

    def exit_unary_expr(self, node: uni.UnaryExpr) -> None:
        op_tok = Tok(node.op.name) if node.op.name in Tok.__members__ else None
        op_cls = UNARY_OP_MAP.get(op_tok) if op_tok else None
        if op_cls:
            node.gen.py_ast = [
                self.sync(
                    ast3.UnaryOp(
                        op=self.sync(op_cls()),
                        operand=cast(ast3.expr, node.operand.gen.py_ast[0]),
                    )
                )
            ]
            return
        elif node.op.name in [Tok.PIPE_FWD, Tok.KW_SPAWN, Tok.A_PIPE_FWD]:
            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=cast(ast3.expr, node.operand.gen.py_ast[0]),
                        args=[],
                        keywords=[],
                    )
                )
            ]
        elif node.op.name in [Tok.STAR_MUL]:
            ctx_val = (
                node.operand.py_ctx_func()
                if isinstance(node.operand, uni.AstSymbolNode)
                else ast3.Load()
            )
            node.gen.py_ast = [
                self.sync(
                    ast3.Starred(
                        value=cast(ast3.expr, node.operand.gen.py_ast[0]),
                        ctx=cast(ast3.expr_context, ctx_val),
                    )
                )
            ]
        elif node.op.name in [Tok.STAR_POW]:
            node.gen.py_ast = node.operand.gen.py_ast
        elif node.op.name in [Tok.BW_AND]:
            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=self.builtin_name("jobj"),
                        args=[],
                        keywords=[
                            self.sync(
                                ast3.keyword(
                                    arg="id",
                                    value=cast(ast3.expr, node.operand.gen.py_ast[0]),
                                )
                            ),
                        ],
                    )
                )
            ]
        else:
            self.ice(f"Unknown Unary operator {node.op.value}")

    def exit_if_else_expr(self, node: uni.IfElseExpr) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.IfExp(
                    test=cast(ast3.expr, node.condition.gen.py_ast[0]),
                    body=cast(ast3.expr, node.value.gen.py_ast[0]),
                    orelse=cast(ast3.expr, node.else_value.gen.py_ast[0]),
                )
            )
        ]

    def exit_multi_string(self, node: uni.MultiString) -> None:
        def get_pieces(str_seq: Sequence) -> list[str | ast3.AST]:
            pieces: list[str | ast3.AST] = []
            for i in str_seq:
                if isinstance(i, uni.String):
                    pieces.append(i.lit_value)
                elif isinstance(i, (uni.FString, uni.ExprStmt)):
                    # pieces.extend(get_pieces(i.parts)) if i.parts else None
                    pieces.append(i.gen.py_ast[0])
                elif isinstance(i, uni.Token) and i.name in [Tok.LBRACE, Tok.RBRACE]:
                    continue
                else:
                    raise self.ice("Multi string made of something weird.")
            return pieces

        combined_multi: list[str | bytes | ast3.AST] = []
        for item in get_pieces(node.strings):
            if (
                combined_multi
                and isinstance(item, str)
                and isinstance(combined_multi[-1], str)
            ):
                if isinstance(combined_multi[-1], str):
                    combined_multi[-1] += item
            elif (
                combined_multi
                and isinstance(item, bytes)
                and isinstance(combined_multi[-1], bytes)
            ):
                combined_multi[-1] += item
            else:
                combined_multi.append(item)
        for i, val in enumerate(combined_multi):
            if isinstance(val, (str, bytes)):
                combined_multi[i] = self.sync(ast3.Constant(value=val))
        if len(combined_multi) > 1 or not isinstance(combined_multi[0], ast3.Constant):
            node.gen.py_ast = [
                self.sync(
                    ast3.JoinedStr(
                        values=[cast(ast3.expr, node) for node in combined_multi],
                    )
                )
            ]
        else:
            node.gen.py_ast = [combined_multi[0]]

    def exit_f_string(self, node: uni.FString) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.JoinedStr(
                    values=[
                        cast(ast3.expr, part.gen.py_ast[0])
                        for part in node.parts
                        if part.gen.py_ast
                    ],
                )
            )
        ]

    def exit_formatted_value(self, node: uni.FormattedValue) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.FormattedValue(
                    value=cast(ast3.expr, node.format_part.gen.py_ast[0]),
                    conversion=node.conversion,
                    format_spec=(
                        cast(ast3.expr, node.format_spec.gen.py_ast[0])
                        if node.format_spec
                        else None
                    ),
                )
            )
        ]

    def exit_list_val(self, node: uni.ListVal) -> None:
        elts = [cast(ast3.expr, v.gen.py_ast[0]) for v in node.values]
        ctx = (
            ast3.Load()
            if isinstance(node.py_ctx_func(), ast3.Load)
            else cast(ast3.expr_context, node.py_ctx_func())
        )
        node.gen.py_ast = [self.sync(ast3.List(elts=elts, ctx=ctx))]

    def exit_set_val(self, node: uni.SetVal) -> None:
        elts = [cast(ast3.expr, i.gen.py_ast[0]) for i in node.values]
        node.gen.py_ast = [self.sync(ast3.Set(elts=elts))]

    def exit_tuple_val(self, node: uni.TupleVal) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.Tuple(
                    elts=[cast(ast3.expr, i.gen.py_ast[0]) for i in node.values],
                    ctx=cast(ast3.expr_context, node.py_ctx_func()),
                )
            )
        ]

    def exit_dict_val(self, node: uni.DictVal) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.Dict(
                    keys=[
                        cast(ast3.expr, x.key.gen.py_ast[0]) if x.key else None
                        for x in node.kv_pairs
                    ],
                    values=[
                        cast(ast3.expr, x.value.gen.py_ast[0]) for x in node.kv_pairs
                    ],
                )
            )
        ]

    def exit_k_v_pair(self, node: uni.KVPair) -> None:
        pass

    def exit_k_w_pair(self, node: uni.KWPair) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.keyword(
                    arg=(
                        node.key.gen.py_ast[0].id
                        if node.key and isinstance(node.key.gen.py_ast[0], ast3.Name)
                        else None
                    ),
                    value=cast(ast3.expr, node.value.gen.py_ast[0]),
                )
            )
        ]

    def exit_inner_compr(self, node: uni.InnerCompr) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.comprehension(
                    target=cast(ast3.expr, node.target.gen.py_ast[0]),
                    iter=cast(ast3.expr, node.collection.gen.py_ast[0]),
                    ifs=(
                        [cast(ast3.expr, x.gen.py_ast[0]) for x in node.conditional]
                        if node.conditional
                        else []
                    ),
                    is_async=0,
                )
            )
        ]

    def exit_list_compr(self, node: uni.ListCompr) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.ListComp(
                    elt=cast(ast3.expr, node.out_expr.gen.py_ast[0]),
                    generators=cast(
                        list[ast3.comprehension], [i.gen.py_ast[0] for i in node.compr]
                    ),
                )
            )
        ]

    def exit_gen_compr(self, node: uni.GenCompr) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.GeneratorExp(
                    elt=cast(ast3.expr, node.out_expr.gen.py_ast[0]),
                    generators=[
                        cast(ast3.comprehension, i.gen.py_ast[0]) for i in node.compr
                    ],
                )
            )
        ]

    def exit_set_compr(self, node: uni.SetCompr) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.SetComp(
                    elt=cast(ast3.expr, node.out_expr.gen.py_ast[0]),
                    generators=[
                        cast(ast3.comprehension, i.gen.py_ast[0]) for i in node.compr
                    ],
                )
            )
        ]

    def exit_dict_compr(self, node: uni.DictCompr) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.DictComp(
                    key=(
                        cast(ast3.expr, node.kv_pair.key.gen.py_ast[0])
                        if node.kv_pair.key
                        else cast(ast3.expr, ast3.Constant(value=None))
                    ),
                    value=cast(ast3.expr, node.kv_pair.value.gen.py_ast[0]),
                    generators=[
                        cast(ast3.comprehension, i.gen.py_ast[0]) for i in node.compr
                    ],
                )
            )
        ]

    def exit_atom_trailer(self, node: uni.AtomTrailer) -> None:
        if node.is_genai:
            node.gen.py_ast = []
        if node.is_attr:
            if isinstance(node.right, uni.AstSymbolNode):
                node.gen.py_ast = [
                    self.sync(
                        ast3.Attribute(
                            value=cast(ast3.expr, node.target.gen.py_ast[0]),
                            attr=node.right.sym_name,
                            ctx=cast(ast3.expr_context, node.right.py_ctx_func()),
                        )
                    )
                ]
            else:
                self.log_error("Invalid attribute access")
        elif isinstance(node.right, uni.FilterCompr):
            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("filter_on"),
                        args=[],
                        keywords=[
                            self.sync(
                                ast3.keyword(
                                    arg="items",
                                    value=cast(ast3.expr, node.target.gen.py_ast[0]),
                                )
                            ),
                            self.sync(
                                ast3.keyword(
                                    arg="func",
                                    value=cast(ast3.expr, node.right.gen.py_ast[0]),
                                )
                            ),
                        ],
                    )
                )
            ]
        elif isinstance(node.right, uni.AssignCompr):
            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("assign_all"),
                        args=cast(
                            list[ast3.expr],
                            [node.target.gen.py_ast[0], node.right.gen.py_ast[0]],
                        ),
                        keywords=[],
                    )
                )
            ]
        else:
            node.gen.py_ast = [
                self.sync(
                    ast3.Subscript(
                        value=cast(ast3.expr, node.target.gen.py_ast[0]),
                        slice=cast(ast3.expr, node.right.gen.py_ast[0]),
                        ctx=(
                            cast(ast3.expr_context, node.right.py_ctx_func())
                            if isinstance(node.right, uni.AstSymbolNode)
                            else ast3.Load()
                        ),
                    )
                )
            ]
            node.right.gen.py_ast[0].ctx = ast3.Load()  # type: ignore

        if node.is_null_ok:
            walrus_assign = self.sync(
                ast3.NamedExpr(
                    target=self.sync(ast3.Name(id="__jac_tmp", ctx=ast3.Store())),
                    value=cast(ast3.expr, node.target.gen.py_ast[0]),
                )
            )
            tmp_ref = self.sync(ast3.Name(id="__jac_tmp", ctx=ast3.Load()))
            none_const = self.sync(ast3.Constant(value=None))

            # Determine the body expression based on the operation type
            body_expr: ast3.expr
            if isinstance(node.gen.py_ast[0], ast3.Attribute):
                body_expr = self.sync(
                    ast3.Call(
                        func=self.sync(ast3.Name(id="getattr", ctx=ast3.Load())),
                        args=[
                            tmp_ref,
                            self.sync(ast3.Constant(value=node.gen.py_ast[0].attr)),
                            none_const,
                        ],
                        keywords=[],
                    )
                )
            elif isinstance(node.gen.py_ast[0], ast3.Call):
                call_node = node.gen.py_ast[0]
                if isinstance(call_node.func, ast3.Attribute) or (
                    isinstance(call_node.func, ast3.Name)
                    and call_node.func.id == "filter_on"
                ):
                    for kw in call_node.keywords:
                        if kw.arg == "items":
                            kw.value = tmp_ref
                if (
                    isinstance(call_node.func, ast3.Attribute)
                    or (
                        isinstance(call_node.func, ast3.Name)
                        and call_node.func.id == "assign_all"
                    )
                ) and call_node.args:
                    call_node.args[0] = tmp_ref
                body_expr = cast(ast3.expr, call_node)
            else:
                if isinstance(node.gen.py_ast[0], ast3.Subscript):
                    # Use safe_subscript helper that handles all cases safely
                    index_expr = node.gen.py_ast[0].slice

                    body_expr = self.sync(
                        ast3.Call(
                            func=self.jaclib_obj("safe_subscript"),
                            args=[tmp_ref, index_expr],
                            keywords=[],
                        )
                    )
                else:
                    # Fallback for any other operation type
                    node.gen.py_ast[0].value = tmp_ref  # type: ignore[attr-defined]
                    body_expr = cast(ast3.expr, node.gen.py_ast[0])

            # Generate: body_expr if (__jac_tmp := target) is not None else None
            node.gen.py_ast = [
                self.sync(
                    ast3.IfExp(
                        test=self.sync(
                            ast3.Compare(
                                left=walrus_assign,
                                ops=[self.sync(ast3.IsNot())],
                                comparators=[none_const],
                            )
                        ),
                        body=body_expr,
                        orelse=none_const,
                    )
                )
            ]

    def exit_atom_unit(self, node: uni.AtomUnit) -> None:
        if (
            isinstance(node.value, uni.Ability)
            and node.value.gen.py_ast
            and isinstance(
                node.value.gen.py_ast[0], (ast3.FunctionDef, ast3.AsyncFunctionDef)
            )
        ):
            func_ast = cast(
                ast3.FunctionDef | ast3.AsyncFunctionDef, node.value.gen.py_ast[0]
            )
            node.gen.py_ast = [
                self._function_expr_from_def(
                    func_def=func_ast,
                    jac_node=node,
                    filename_hint=f"<jac_iife:{func_ast.name}>",
                )
            ]
            return
        node.gen.py_ast = node.value.gen.py_ast

    def gen_call_args(
        self, node: uni.FuncCall
    ) -> tuple[list[ast3.expr], list[ast3.keyword]]:
        """Generate the arguments for a function call."""
        args = []
        keywords = []
        if node.params:
            for x in node.params:
                if isinstance(x, uni.UnaryExpr) and x.op.name == Tok.STAR_POW:
                    keywords.append(
                        self.sync(
                            ast3.keyword(
                                value=cast(ast3.expr, x.operand.gen.py_ast[0])
                            ),
                            x,
                        )
                    )
                elif isinstance(x, uni.Expr):
                    args.append(cast(ast3.expr, x.gen.py_ast[0]))
                elif isinstance(x, uni.KWPair) and isinstance(
                    x.gen.py_ast[0], ast3.keyword
                ):
                    keywords.append(x.gen.py_ast[0])
                else:
                    self.ice("Invalid Parameter")
        return args, keywords

    def exit_func_call(self, node: uni.FuncCall) -> None:
        # TODO: This needs to be changed to only generate parameters no the body.
        if node.genai_call:
            self.ice("Type(by llm()) call feature is temporarily disabled.")

        else:
            func = node.target.gen.py_ast[0]
            args, keywords = self.gen_call_args(node)

            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=cast(ast3.expr, func),
                        args=[cast(ast3.expr, arg) for arg in args],
                        keywords=keywords,
                    )
                )
            ]

    def exit_index_slice(self, node: uni.IndexSlice) -> None:
        if node.is_range:
            if len(node.slices) > 1:  # Multiple slices. Example arr[a:b, c:d]
                node.gen.py_ast = [
                    self.sync(
                        ast3.Tuple(
                            elts=[
                                self.sync(
                                    ast3.Slice(
                                        lower=(
                                            cast(ast3.expr, slice.start.gen.py_ast[0])
                                            if slice.start
                                            else None
                                        ),
                                        upper=(
                                            cast(ast3.expr, slice.stop.gen.py_ast[0])
                                            if slice.stop
                                            else None
                                        ),
                                        step=(
                                            cast(ast3.expr, slice.step.gen.py_ast[0])
                                            if slice.step
                                            else None
                                        ),
                                    )
                                )
                                for slice in node.slices
                            ],
                            ctx=ast3.Load(),
                        )
                    )
                ]
            elif len(node.slices) == 1:  # Single slice. Example arr[a]
                slice = node.slices[0]
                node.gen.py_ast = [
                    self.sync(
                        ast3.Slice(
                            lower=(
                                cast(ast3.expr, slice.start.gen.py_ast[0])
                                if slice.start
                                else None
                            ),
                            upper=(
                                cast(ast3.expr, slice.stop.gen.py_ast[0])
                                if slice.stop
                                else None
                            ),
                            step=(
                                cast(ast3.expr, slice.step.gen.py_ast[0])
                                if slice.step
                                else None
                            ),
                        )
                    )
                ]
        else:
            if len(node.slices) > 0 and node.slices[0].start is not None:
                node.gen.py_ast = node.slices[0].start.gen.py_ast
            else:
                node.gen.py_ast = []

    def exit_special_var_ref(self, node: uni.SpecialVarRef) -> None:
        if node.name == Tok.KW_SUPER:
            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=self.sync(ast3.Name(id="super", ctx=node.py_ctx_func())),
                        args=[],
                        keywords=[],
                    )
                )
            ]
        elif node.name == Tok.KW_ROOT:
            node.gen.py_ast = [
                self.sync(
                    ast3.Call(
                        func=self.jaclib_obj("root"),
                        args=[],
                        keywords=[],
                    )
                )
            ]

        else:
            node.gen.py_ast = [
                self.sync(ast3.Name(id=node.sym_name, ctx=node.py_ctx_func()))
            ]

    def exit_edge_ref_trailer(self, node: uni.EdgeRefTrailer) -> None:
        origin = None
        cur = node.chain[0]
        chomp = [*node.chain[1:]]
        from_visit = bool(isinstance(node.parent, uni.VisitStmt))

        if not isinstance(cur, uni.EdgeOpRef):
            origin = cur.gen.py_ast[0]
            cur = cast(uni.EdgeOpRef, chomp.pop(0))

        pynode = self.sync(
            ast3.Call(
                func=self.jaclib_obj("OPath"),
                args=[cast(ast3.expr, origin or cur.gen.py_ast[0])],
                keywords=[],
            )
        )

        while True:
            keywords = []
            if cur.filter_cond:
                keywords.append(
                    self.sync(
                        ast3.keyword(
                            arg="edge",
                            value=cast(
                                ast3.expr, self.sync(cur.filter_cond.gen.py_ast[0])
                            ),
                        )
                    )
                )

            if chomp and not isinstance(chomp[0], uni.EdgeOpRef):
                filt = chomp.pop(0)
                keywords.append(
                    self.sync(
                        ast3.keyword(
                            arg="node",
                            value=cast(ast3.expr, self.sync(filt.gen.py_ast[0])),
                        )
                    )
                )

            pynode = self.sync(
                ast3.Call(
                    func=self.sync(
                        ast3.Attribute(
                            value=pynode,
                            attr=f"edge_{cur.edge_dir.name.lower()}",
                            ctx=ast3.Load(),
                        )
                    ),
                    args=[],
                    keywords=keywords,
                )
            )

            if chomp:
                cur = cast(uni.EdgeOpRef, chomp.pop(0))
            else:
                break

        if node.edges_only:
            pynode = self.sync(
                ast3.Call(
                    func=self.sync(
                        ast3.Attribute(
                            value=pynode,
                            attr="edge",
                            ctx=ast3.Load(),
                        )
                    ),
                    args=[],
                    keywords=[],
                )
            )

        if from_visit:
            pynode = self.sync(
                ast3.Call(
                    func=self.sync(
                        ast3.Attribute(
                            value=pynode,
                            attr="visit",
                            ctx=ast3.Load(),
                        )
                    ),
                    args=[],
                    keywords=[],
                )
            )
        if node.is_async:
            pynode = self.sync(
                ast3.Call(
                    func=self.jaclib_obj("arefs"),
                    args=[pynode],
                    keywords=[],
                )
            )
        else:
            pynode = self.sync(
                ast3.Call(
                    func=self.jaclib_obj("refs"),
                    args=[pynode],
                    keywords=[],
                )
            )

        node.gen.py_ast = [pynode]

    def exit_edge_op_ref(self, node: uni.EdgeOpRef) -> None:
        loc = self.sync(
            ast3.Name(id=Con.HERE.value, ctx=ast3.Load())
            if node.from_walker
            else ast3.Name(id="self", ctx=ast3.Load())
        )
        node.gen.py_ast = [loc]

    def exit_disconnect_op(self, node: uni.DisconnectOp) -> None:
        node.gen.py_ast = node.edge_spec.gen.py_ast

    def exit_connect_op(self, node: uni.ConnectOp) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.Call(
                    func=self.jaclib_obj("build_edge"),
                    args=[],
                    keywords=[
                        self.sync(
                            ast3.keyword(
                                arg="is_undirected",
                                value=self.sync(
                                    ast3.Constant(value=node.edge_dir == EdgeDir.ANY)
                                ),
                            )
                        ),
                        self.sync(
                            ast3.keyword(
                                arg="conn_type",
                                value=(
                                    cast(ast3.expr, node.conn_type.gen.py_ast[0])
                                    if node.conn_type
                                    else self.sync(ast3.Constant(value=None))
                                ),
                            )
                        ),
                        self.sync(
                            ast3.keyword(
                                arg="conn_assign",
                                value=(
                                    cast(ast3.expr, node.conn_assign.gen.py_ast[0])
                                    if node.conn_assign
                                    else self.sync(ast3.Constant(value=None))
                                ),
                            )
                        ),
                    ],
                )
            )
        ]

    def exit_filter_compr(self, node: uni.FilterCompr) -> None:
        iter_name = "i"

        comprs: list[ast3.Compare | ast3.Call] = (
            [
                self.sync(
                    ast3.Call(
                        func=self.sync(
                            ast3.Name(
                                id="isinstance",
                                ctx=ast3.Load(),
                            )
                        ),
                        args=cast(
                            list[ast3.expr],
                            [
                                self.sync(
                                    ast3.Name(
                                        id=iter_name,
                                        ctx=ast3.Load(),
                                    )
                                ),
                                self.sync(node.f_type.gen.py_ast[0]),
                            ],
                        ),
                        keywords=[],
                    )
                )
            ]
            if node.f_type
            else []
        )
        comprs.extend(
            self.sync(
                ast3.Compare(
                    left=self.sync(
                        ast3.Attribute(
                            value=self.sync(
                                ast3.Name(
                                    id=iter_name,
                                    ctx=ast3.Load(),
                                ),
                                jac_node=x,
                            ),
                            attr=x.gen.py_ast[0].left.id,
                            ctx=ast3.Load(),
                        ),
                        jac_node=x,
                    ),
                    ops=x.gen.py_ast[0].ops,
                    comparators=x.gen.py_ast[0].comparators,
                ),
                jac_node=x,
            )
            for x in node.compares
            if isinstance(x.gen.py_ast[0], ast3.Compare)
            and isinstance(x.gen.py_ast[0].left, ast3.Name)
        )

        if body := (
            self.sync(
                ast3.BoolOp(
                    op=self.sync(ast3.And()),
                    values=[cast(ast3.expr, item) for item in comprs],
                )
            )
            if len(comprs) > 1
            else (comprs[0] if comprs else None)
        ):
            node.gen.py_ast = [
                self.sync(
                    ast3.Lambda(
                        args=self.sync(
                            ast3.arguments(
                                posonlyargs=[],
                                args=[self.sync(ast3.arg(arg=iter_name))],
                                kwonlyargs=[],
                                kw_defaults=[],
                                defaults=[],
                            )
                        ),
                        body=body,
                    )
                )
            ]

    def exit_assign_compr(self, node: uni.AssignCompr) -> None:
        keys = []
        values = []
        for i in node.assigns:
            if i.key:  # TODO: add support for **kwargs in assign_compr
                keys.append(self.sync(ast3.Constant(i.key.sym_name)))
                values.append(i.value.gen.py_ast[0])
        key_tup = self.sync(
            ast3.Tuple(
                elts=[key for key in keys if isinstance(key, ast3.expr)],
                ctx=ast3.Load(),
            )
        )
        val_tup = self.sync(
            ast3.Tuple(
                elts=[v for v in values if isinstance(v, ast3.expr)], ctx=ast3.Load()
            )
        )
        node.gen.py_ast = [
            self.sync(ast3.Tuple(elts=[key_tup, val_tup], ctx=ast3.Load()))
        ]

    def exit_match_stmt(self, node: uni.MatchStmt) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.Match(
                    subject=cast(ast3.expr, node.target.gen.py_ast[0]),
                    cases=[cast(ast3.match_case, x.gen.py_ast[0]) for x in node.cases],
                )
            )
        ]

    def exit_match_case(self, node: uni.MatchCase) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.match_case(
                    pattern=cast(ast3.pattern, node.pattern.gen.py_ast[0]),
                    guard=(
                        cast(ast3.expr, node.guard.gen.py_ast[0])
                        if node.guard
                        else None
                    ),
                    body=[cast(ast3.stmt, x.gen.py_ast[0]) for x in node.body],
                )
            )
        ]

    def exit_match_or(self, node: uni.MatchOr) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.MatchOr(
                    patterns=[
                        cast(ast3.pattern, x.gen.py_ast[0]) for x in node.patterns
                    ],
                )
            )
        ]

    def exit_match_as(self, node: uni.MatchAs) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.MatchAs(
                    name=node.name.sym_name,
                    pattern=(
                        cast(ast3.pattern, node.pattern.gen.py_ast[0])
                        if node.pattern
                        else None
                    ),
                )
            )
        ]

    def exit_match_wild(self, node: uni.MatchWild) -> None:
        node.gen.py_ast = [self.sync(ast3.MatchAs())]

    def exit_match_value(self, node: uni.MatchValue) -> None:
        node.gen.py_ast = [
            self.sync(ast3.MatchValue(value=cast(ast3.expr, node.value.gen.py_ast[0])))
        ]

    def exit_match_singleton(self, node: uni.MatchSingleton) -> None:
        node.gen.py_ast = [self.sync(ast3.MatchSingleton(value=node.value.lit_value))]

    def exit_match_sequence(self, node: uni.MatchSequence) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.MatchSequence(
                    patterns=[cast(ast3.pattern, x.gen.py_ast[0]) for x in node.values],
                )
            )
        ]

    def exit_match_mapping(self, node: uni.MatchMapping) -> None:
        mapping = self.sync(ast3.MatchMapping(keys=[], patterns=[], rest=None))
        for i in node.values:
            if (
                isinstance(i, uni.MatchKVPair)
                and isinstance(i.key, uni.MatchValue)
                and isinstance(i.key.value.gen.py_ast[0], ast3.expr)
                and isinstance(i.value.gen.py_ast[0], ast3.pattern)
            ):
                mapping.keys.append(i.key.value.gen.py_ast[0])
                mapping.patterns.append(i.value.gen.py_ast[0])
            elif isinstance(i, uni.MatchStar):
                mapping.rest = i.name.sym_name
        node.gen.py_ast = [mapping]

    def exit_match_k_v_pair(self, node: uni.MatchKVPair) -> None:
        pass

    def exit_match_star(self, node: uni.MatchStar) -> None:
        node.gen.py_ast = [self.sync(ast3.MatchStar(name=node.name.sym_name))]

    def exit_match_arch(self, node: uni.MatchArch) -> None:
        node.gen.py_ast = [
            self.sync(
                ast3.MatchClass(
                    cls=cast(ast3.expr, node.name.gen.py_ast[0]),
                    patterns=[
                        cast(ast3.pattern, x.gen.py_ast[0])
                        for x in (node.arg_patterns or [])
                    ],
                    kwd_attrs=[
                        x.key.sym_name
                        for x in (node.kw_patterns or [])
                        if isinstance(x.key, uni.NameAtom)
                    ],
                    kwd_patterns=[
                        cast(ast3.pattern, x.value.gen.py_ast[0])
                        for x in (node.kw_patterns or [])
                    ],
                )
            )
        ]

    def exit_token(self, node: uni.Token) -> None:
        tok = Tok(node.name) if node.name in Tok.__members__ else None
        op_cls = TOKEN_AST_MAP.get(tok) if tok else None
        if op_cls:
            node.gen.py_ast = [self.sync(op_cls())]

    def exit_name(self, node: uni.Name) -> None:
        name = node.sym_name
        if name in self._get_builtin_names():
            self.builtin_imports.add(name)
        node.gen.py_ast = [self.sync(ast3.Name(id=name, ctx=node.py_ctx_func()))]

    def exit_float(self, node: uni.Float) -> None:
        node.gen.py_ast = [self.sync(ast3.Constant(value=float(node.value)))]

    def exit_int(self, node: uni.Int) -> None:
        node.gen.py_ast = [self.sync(ast3.Constant(value=int(node.value, 0)))]

    def exit_string(self, node: uni.String) -> None:
        node.gen.py_ast = [self.sync(ast3.Constant(value=node.lit_value))]

    def exit_bool(self, node: uni.Bool) -> None:
        node.gen.py_ast = [self.sync(ast3.Constant(value=node.value == "True"))]

    def exit_builtin_type(self, node: uni.BuiltinType) -> None:
        node.gen.py_ast = [
            self.sync(ast3.Name(id=node.sym_name, ctx=node.py_ctx_func()))
        ]

    def exit_null(self, node: uni.Null) -> None:
        node.gen.py_ast = [self.sync(ast3.Constant(value=None))]

    def exit_ellipsis(self, node: uni.Ellipsis) -> None:
        node.gen.py_ast = [self.sync(ast3.Constant(value=...))]

    def exit_jsx_element(self, node: uni.JsxElement) -> None:
        """Generate Python AST for JSX elements."""
        self.jsx_processor.element(node)

    def exit_jsx_element_name(self, node: uni.JsxElementName) -> None:
        """Generate Python AST for JSX element names."""
        self.jsx_processor.element_name(node)

    def exit_jsx_attribute(self, node: uni.JsxAttribute) -> None:
        """Bases class for JSX attributes - handled by subclasses."""
        pass

    def exit_jsx_spread_attribute(self, node: uni.JsxSpreadAttribute) -> None:
        """Generate Python AST for JSX spread attributes."""
        self.jsx_processor.spread_attribute(node)

    def exit_jsx_normal_attribute(self, node: uni.JsxNormalAttribute) -> None:
        """Generate Python AST for JSX normal attributes."""
        self.jsx_processor.normal_attribute(node)

    def exit_jsx_child(self, node: uni.JsxChild) -> None:
        """Bases class for JSX children - handled by subclasses."""
        pass

    def exit_jsx_text(self, node: uni.JsxText) -> None:
        """Generate Python AST for JSX text nodes."""
        self.jsx_processor.text(node)

    def exit_jsx_expression(self, node: uni.JsxExpression) -> None:
        """Generate Python AST for JSX expression children."""
        self.jsx_processor.expression(node)

    def exit_semi(self, node: uni.Semi) -> None:
        pass

    def exit_comment_token(self, node: uni.CommentToken) -> None:
        pass

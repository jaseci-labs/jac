"""LLVM IR generation pass for Jac programs using llvmlite.

This pass walks the Jac core AST (unitree) and emits a best-effort LLVM IR
module for plain ``def`` abilities. The initial implementation focuses on the
core building blocks required to execute straight-line numeric code and is
designed to be incrementally extended as more Jac constructs gain native
support.
"""

from __future__ import annotations

from typing import Any, Optional, Sequence

import jaclang.compiler.unitree as uni
from jaclang.compiler.constant import Tokens as Tok
from jaclang.compiler.passes.ast_gen.base_ast_gen_pass import BaseAstGenPass

try:  # pragma: no cover - optional dependency, exercised in integration tests
    import llvmlite.binding as _llvm
    import llvmlite.ir as _ir
except ImportError:  # pragma: no cover - exercised only when llvmlite missing
    _llvm = None
    _ir = None


class LlvmIrGenPass(BaseAstGenPass[Any]):
    """Generate LLVM IR for Jac abilities."""

    _llvm_initialized = False

    def before_pass(self) -> None:  # noqa: D401 - documented in class docstring
        if _llvm is None or _ir is None:
            raise ImportError(
                "llvmlite is required to run the LlvmIrGenPass. "
                "Install it with `pip install llvmlite`."
            )

        self.child_passes: list[LlvmIrGenPass] = self._init_child_passes(LlvmIrGenPass)

        if not LlvmIrGenPass._llvm_initialized:
            _llvm.initialize()
            _llvm.initialize_native_target()
            _llvm.initialize_native_asmprinter()
            LlvmIrGenPass._llvm_initialized = True

        target = _llvm.Target.from_default_triple()
        self._target_machine = target.create_target_machine()
        self._triple = _llvm.get_default_triple()
        self._data_layout = str(self._target_machine.target_data)

        self.module_stack: list[_ir.Module] = []
        self.builder_stack: list[_ir.IRBuilder] = []
        self.symbol_stack: list[dict[str, Any]] = []
        self.function_stack: list[_ir.Function] = []
        self.metadata_stack: list[dict[str, Any]] = []

        self._int_type = _ir.IntType(64)
        self._bool_type = _ir.IntType(1)
        self._float_type = _ir.DoubleType()
        self._void_type = _ir.VoidType()

    # --------------------------------------------------------------------- utils
    @property
    def _builder(self) -> Optional[_ir.IRBuilder]:
        return self.builder_stack[-1] if self.builder_stack else None

    @property
    def _module(self) -> Optional[_ir.Module]:
        return self.module_stack[-1] if self.module_stack else None

    @property
    def _function(self) -> Optional[_ir.Function]:
        return self.function_stack[-1] if self.function_stack else None

    def _with_builder(self, builder: _ir.IRBuilder) -> _ir.IRBuilder:
        self.builder_stack.append(builder)
        return builder

    def _pop_builder(self) -> None:
        if self.builder_stack:
            self.builder_stack.pop()

    # ------------------------------------------------------------------- modules
    def enter_module(self, node: uni.Module) -> None:
        module_name = node.name or node.loc.mod_path or "jac_module"
        sanitized = module_name.replace(".", "_")
        llvm_module = _ir.Module(name=sanitized)
        llvm_module.triple = self._triple
        llvm_module.data_layout = self._data_layout
        self.module_stack.append(llvm_module)
        self.metadata_stack.append({})

    def exit_module(self, node: uni.Module) -> None:
        if not self.module_stack:
            return
        llvm_module = self.module_stack.pop()
        metadata = self.metadata_stack.pop() if self.metadata_stack else {}
        node.gen.llvm_module = llvm_module
        node.gen.llvm_ir = str(llvm_module)
        node.gen.llvm_metadata = metadata
        node.gen.llvm_triple = self._triple
        node.gen.llvm_data_layout = self._data_layout

    # ---------------------------------------------------------------- abilities
    def enter_ability(self, node: uni.Ability) -> None:
        # Only support plain def abilities for now.
        if not self._module or not node.is_def or node.is_async or node.is_method:
            self.prune()
            return

        if not isinstance(node.body, Sequence):
            self.log_error(
                "Only code block abilities are supported by the LLVM backend.",
                node_override=node,
            )
            self.prune()
            return

        signature = (
            node.signature if isinstance(node.signature, uni.FuncSignature) else None
        )
        params = signature.get_parameters() if signature else []

        arg_types: list[_ir.Type] = []
        arg_names: list[str] = []
        for param in params:
            if param.is_vararg or param.is_kwargs:
                self.log_error(
                    "Variadic parameters are not yet supported by the LLVM backend.",
                    node_override=param,
                )
                self.prune()
                return
            llvm_type = self._resolve_annotation(
                param.type_tag.tag if param.type_tag else None
            )
            arg_types.append(llvm_type)
            arg_names.append(param.name.value)

        return_type = (
            self._resolve_annotation(signature.return_type)
            if signature
            else self._int_type
        )
        func_type = _ir.FunctionType(return_type, arg_types)
        func_name = node.py_resolve_name()
        llvm_func = _ir.Function(self._module, func_type, name=func_name)
        entry_block = llvm_func.append_basic_block("entry")
        builder = self._with_builder(_ir.IRBuilder(entry_block))

        self.function_stack.append(llvm_func)
        self.symbol_stack.append({})
        metadata = self.metadata_stack[-1] if self.metadata_stack else {}
        metadata[func_name] = {
            "return": self._encode_type(return_type),
            "args": [self._encode_type(t) for t in arg_types],
        }

        # Assign parameters to allocas so they can be referenced uniformly.
        for ir_arg, name in zip(llvm_func.args, arg_names):
            ir_arg.name = name
            alloca = self._create_entry_alloca(name, ir_arg.type)
            builder.store(ir_arg, alloca)
            self.symbol_stack[-1][name] = alloca

        node.gen.llvm_module = self._module
        node.gen.llvm_function = llvm_func

        self._compile_block(node.body)

        # Emit an implicit return if the function did not return explicitly.
        if builder.block.terminator is None:
            default_value = self._default_value(return_type, node)
            if default_value is None:
                builder.ret_void()
            else:
                builder.ret(default_value)

        self._pop_builder()
        self.function_stack.pop()
        self.symbol_stack.pop()
        self.prune()

    # ------------------------------------------------------------- code emitters
    def _compile_block(self, block: Sequence[uni.CodeBlockStmt]) -> None:
        for stmt in block:
            self._compile_stmt(stmt)
            if self._builder is None or self._builder.block.terminator is not None:
                break

    def _compile_stmt(self, stmt: uni.CodeBlockStmt) -> None:
        if self._builder is None:
            return
        if isinstance(stmt, uni.ReturnStmt):
            self._compile_return(stmt)
        elif isinstance(stmt, uni.Assignment):
            self._compile_assignment(stmt)
        elif isinstance(stmt, uni.ExprStmt):
            self._compile_expr(stmt.expr)
        elif isinstance(stmt, uni.Semi):
            return
        else:
            self.log_warning(
                f"Statement '{type(stmt).__name__}' is not supported by the LLVM backend yet.",
                node_override=stmt,
            )

    def _compile_return(self, node: uni.ReturnStmt) -> None:
        if self._builder is None or self._function is None:
            return

        ret_type = self._function.function_type.return_type

        if node.expr is None:
            default_value = self._default_value(ret_type, node)
            if default_value is None:
                self._builder.ret_void()
            else:
                self._builder.ret(default_value)
            return

        value = self._compile_expr(node.expr)
        if value is None:
            return

        coerced = self._coerce(value, ret_type, node)
        if coerced is None:
            return
        self._builder.ret(coerced)

    def _compile_assignment(self, node: uni.Assignment) -> None:
        if self._builder is None:
            return

        if len(node.target) != 1:
            self.log_error(
                "Only single-target assignments are supported by the LLVM backend.",
                node_override=node,
            )
            return

        target_expr = node.target[0]
        if not isinstance(target_expr, uni.Name):
            self.log_error(
                "Assignments currently require a simple name on the left-hand side.",
                node_override=node,
            )
            return

        if node.value is None:
            self.log_error(
                "Assignments without an initial value are not supported by the LLVM backend.",
                node_override=node,
            )
            return

        if node.aug_op is not None:
            self.log_warning(
                "Augmented assignments are not yet supported by the LLVM backend.",
                node_override=node,
            )
            return

        value = self._compile_expr(node.value)
        if value is None:
            return

        declared_type = (
            self._resolve_annotation(node.type_tag.tag) if node.type_tag else value.type
        )
        symbol_table = self.symbol_stack[-1]
        target_name = target_expr.value
        alloca = symbol_table.get(target_name)

        if alloca is None:
            alloca = self._create_entry_alloca(target_name, declared_type)
            symbol_table[target_name] = alloca
        current_type = alloca.type.pointee
        store_value = (
            self._coerce(value, current_type, node)
            if str(current_type) != str(value.type)
            else value
        )
        if store_value is None:
            return
        self._builder.store(store_value, alloca)

    # ---------------------------------------------------------------- expressions
    def _compile_expr(self, expr: uni.Expr) -> Optional[_ir.Value]:
        if self._builder is None:
            return None

        if isinstance(expr, uni.Int):
            return _ir.Constant(self._int_type, expr.lit_value)
        if isinstance(expr, uni.Float):
            return _ir.Constant(self._float_type, expr.lit_value)
        if isinstance(expr, uni.Bool):
            return _ir.Constant(self._bool_type, 1 if expr.lit_value else 0)
        if isinstance(expr, uni.Null):
            return _ir.Constant(_ir.PointerType(_ir.IntType(8)), None)
        if isinstance(expr, uni.Name):
            return self._load_symbol(expr)
        if isinstance(expr, uni.BinaryExpr):
            return self._compile_binary(expr)
        if isinstance(expr, uni.UnaryExpr):
            return self._compile_unary(expr)
        if isinstance(expr, uni.AtomUnit):
            return self._compile_expr(expr.value)
        if isinstance(expr, uni.TupleVal) and len(expr.values) == 1:
            return self._compile_expr(expr.values[0])

        self.log_warning(
            f"Expression '{type(expr).__name__}' is not supported by the LLVM backend yet.",
            node_override=expr,
        )
        return None

    def _compile_binary(self, node: uni.BinaryExpr) -> Optional[_ir.Value]:
        left = self._compile_expr(node.left)
        right = self._compile_expr(node.right)
        if left is None or right is None or self._builder is None:
            return None

        left, right = self._align_binary_operands(left, right, node)
        if left is None or right is None:
            return None

        op = node.op.name if isinstance(node.op, uni.Token) else ""
        if op == Tok.PLUS.value:
            return (
                self._builder.fadd(left, right, name="addtmp")
                if self._is_float_type(left.type)
                else self._builder.add(left, right, name="addtmp")
            )
        if op == Tok.MINUS.value:
            return (
                self._builder.fsub(left, right, name="subtmp")
                if self._is_float_type(left.type)
                else self._builder.sub(left, right, name="subtmp")
            )
        if op in (Tok.STAR_MUL.value, Tok.DECOR_OP.value):
            return (
                self._builder.fmul(left, right, name="multmp")
                if self._is_float_type(left.type)
                else self._builder.mul(left, right, name="multmp")
            )
        if op == Tok.DIV.value:
            return (
                self._builder.fdiv(left, right, name="divtmp")
                if self._is_float_type(left.type)
                else self._builder.sdiv(left, right, name="divtmp")
            )
        if op == Tok.EE.value:
            return self._emit_cmp("==", left, right, node)
        if op == Tok.NE.value or op == Tok.EQ.value:
            return self._emit_cmp("!=", left, right, node)
        if op == Tok.GT.value:
            return self._emit_cmp(">", left, right, node)
        if op == Tok.GTE.value:
            return self._emit_cmp(">=", left, right, node)
        if op == Tok.LT.value:
            return self._emit_cmp("<", left, right, node)
        if op == Tok.LTE.value:
            return self._emit_cmp("<=", left, right, node)

        self.log_warning(
            f"Binary operator '{op}' is not supported by the LLVM backend yet.",
            node_override=node,
        )
        return None

    def _compile_unary(self, node: uni.UnaryExpr) -> Optional[_ir.Value]:
        operand = self._compile_expr(node.operand)
        if operand is None or self._builder is None:
            return None
        op = node.op.name if isinstance(node.op, uni.Token) else ""
        if op == Tok.PLUS.value:
            return operand
        if op == Tok.MINUS.value:
            zero = self._zero_like(operand.type)
            if zero is None:
                self.log_error(
                    "Unable to negate operand due to unsupported type.",
                    node_override=node,
                )
                return None
            return (
                self._builder.fsub(zero, operand, name="negtmp")
                if self._is_float_type(operand.type)
                else self._builder.sub(zero, operand, name="negtmp")
            )
        if op == Tok.NOT.value:
            bool_val = self._coerce(operand, self._bool_type, node)
            return (
                self._builder.icmp_unsigned(
                    "==", bool_val, _ir.Constant(self._bool_type, 0)
                )
                if bool_val is not None
                else None
            )

        self.log_warning(
            f"Unary operator '{op}' is not supported by the LLVM backend yet.",
            node_override=node,
        )
        return None

    # ------------------------------------------------------------------ helpers
    def _load_symbol(self, node: uni.Name) -> Optional[_ir.Value]:
        if self._builder is None:
            return None
        for scope in reversed(self.symbol_stack):
            if node.value in scope:
                alloca = scope[node.value]
                return self._builder.load(alloca, name=node.value)
        self.log_error(
            f"Name '{node.value}' is not defined in the current scope.",
            node_override=node,
        )
        return None

    def _align_binary_operands(
        self, left: _ir.Value, right: _ir.Value, node: uni.BinaryExpr
    ) -> tuple[Optional[_ir.Value], Optional[_ir.Value]]:
        if str(left.type) == str(right.type):
            return left, right
        if self._is_float_type(left.type) and self._is_int_type(right.type):
            return left, self._builder.sitofp(right, left.type, name="coerce_rhs")
        if self._is_float_type(right.type) and self._is_int_type(left.type):
            return self._builder.sitofp(left, right.type, name="coerce_lhs"), right
        self.log_error(
            "Type mismatch in binary expression.",
            node_override=node,
        )
        return None, None

    def _emit_cmp(
        self, op: str, left: _ir.Value, right: _ir.Value, node: uni.BinaryExpr
    ) -> Optional[_ir.Value]:
        if self._builder is None:
            return None
        if self._is_float_type(left.type):
            mapping = {
                "==": "oeq",
                "!=": "one",
                "<": "olt",
                "<=": "ole",
                ">": "ogt",
                ">=": "oge",
            }
            pred = mapping.get(op)
            if pred is None:
                self.log_error(
                    f"Unsupported floating point comparison '{op}'.",
                    node_override=node,
                )
                return None
            return self._builder.fcmp_ordered(pred, left, right, name="cmptmp")
        mapping = {
            "==": "==",
            "!=": "!=",
            "<": "<",
            "<=": "<=",
            ">": ">",
            ">=": ">=",
        }
        pred = mapping.get(op)
        if pred is None:
            self.log_error(
                f"Unsupported integer comparison '{op}'.",
                node_override=node,
            )
            return None
        return self._builder.icmp_signed(pred, left, right, name="cmptmp")

    def _create_entry_alloca(self, name: str, typ: _ir.Type) -> _ir.AllocaInstr:
        entry = self._function.entry_basic_block if self._function else None
        builder = _ir.IRBuilder(entry) if entry else self._builder
        if builder is None:
            raise self.ice("Attempted to allocate outside of a function.")
        builder.position_at_end(entry if entry else builder.block)
        return builder.alloca(typ, name=name)

    def _resolve_annotation(self, annotation: Optional[uni.UniNode]) -> _ir.Type:
        if annotation is None:
            return self._int_type
        if isinstance(annotation, uni.SubTag):
            return self._resolve_annotation(annotation.tag)
        if isinstance(annotation, uni.BuiltinType):
            return self._map_builtin(annotation.value)
        if isinstance(annotation, uni.Name):
            return self._map_builtin(annotation.value)
        return self._int_type

    def _map_builtin(self, value: str) -> _ir.Type:
        lowered = value.lower()
        if lowered in {"int", "i64"}:
            return self._int_type
        if lowered in {"bool", "i1"}:
            return self._bool_type
        if lowered in {"float", "double"}:
            return self._float_type
        if lowered == "void":
            return self._void_type
        return self._int_type

    def _encode_type(self, typ: _ir.Type) -> str:
        return str(typ)

    def _default_value(
        self, typ: _ir.Type, node: Optional[uni.UniNode]
    ) -> Optional[_ir.Constant]:
        if self._is_void_type(typ):
            return None
        if self._is_int_type(typ):
            return _ir.Constant(typ, 0)
        if self._is_float_type(typ):
            return _ir.Constant(typ, 0.0)
        if self._is_pointer_type(typ):
            return _ir.Constant(typ, None)
        self.log_error(
            f"Unable to infer a default return value for type '{typ}'.",
            node_override=node,
        )
        return None

    def _coerce(
        self, value: _ir.Value, target: _ir.Type, node: Optional[uni.UniNode]
    ) -> Optional[_ir.Value]:
        if str(value.type) == str(target):
            return value
        if self._is_float_type(target) and self._is_int_type(value.type):
            return (
                self._builder.sitofp(value, target, name="coerce_fp")
                if self._builder
                else None
            )
        if self._is_int_type(target) and self._is_float_type(value.type):
            return (
                self._builder.fptosi(value, target, name="coerce_int")
                if self._builder
                else None
            )
        if self._is_int_type(target) and self._is_int_type(value.type):
            src = self._int_bitwidth(value.type)
            dst = self._int_bitwidth(target)
            if src < dst:
                return (
                    self._builder.sext(value, target, name="sext")
                    if self._builder
                    else None
                )
            if src > dst:
                return (
                    self._builder.trunc(value, target, name="trunc")
                    if self._builder
                    else None
                )
        if self._is_pointer_type(target) and self._is_pointer_type(value.type):
            return (
                self._builder.bitcast(value, target, name="bitcast")
                if self._builder
                else None
            )
        self.log_error(
            f"Cannot coerce value of type '{value.type}' to '{target}'.",
            node_override=node,
        )
        return None

    def _zero_like(self, typ: _ir.Type) -> Optional[_ir.Constant]:
        if self._is_int_type(typ):
            return _ir.Constant(typ, 0)
        if self._is_float_type(typ):
            return _ir.Constant(typ, 0.0)
        return None

    @staticmethod
    def _int_bitwidth(typ: _ir.Type) -> int:
        return getattr(
            typ, "width", int(str(typ)[1:]) if str(typ).startswith("i") else 0
        )

    @staticmethod
    def _is_int_type(typ: _ir.Type) -> bool:
        return str(typ).startswith("i")

    @staticmethod
    def _is_float_type(typ: _ir.Type) -> bool:
        return str(typ) in {"half", "float", "double", "fp128"}

    @staticmethod
    def _is_pointer_type(typ: _ir.Type) -> bool:
        return str(typ).endswith("*")

    @staticmethod
    def _is_void_type(typ: _ir.Type) -> bool:
        return str(typ) == "void"

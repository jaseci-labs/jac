impl NaIRGenPass._python_handle(value: ir.Value) -> ir.Value {
    result = self._codegen_field_access(value, "value", "__JacPythonValue");
    assert result is not None;
    return result;
}

impl NaIRGenPass._python_operation(
    name: str,
    values: list[ir.Value],
    extra: list[ir.Value],
    status: bool = False,
    consume: bool = True
) -> ir.Value {
    boxed = [self._python_box(value, consume=False) for value in values];
    args = [self._python_handle(value) for value in boxed] + extra;
    function = self._get_or_declare_extern(
        "jacpy_" + name, ir.IntType(64), [arg.type for arg in args]
    );
    raw = self.builder.call(function, args);
    result: ir.Value;
    if status {
        self._python_runtime("check", []);
        result = raw;
    } else {
        result = self._python_runtime("result", [raw]);
    }
    self._release_owned_args(
        [
            value
            for (original, value) in zip(values, boxed)
            if value is not original
        ]
    );
    if consume {
        self._release_owned_args(values);
    }
    return result;
}

impl NaIRGenPass._python_binary(
    op: str, left: ir.Value, right: ir.Value, inplace: bool = False
) -> ir.Value {
    if inplace {
        import from jaclang.compiler.frontend.constant { TOKEN_MAP }
        spelling = op[:-1];
        op = next(
            token
            for (token, value) in TOKEN_MAP.items()
            if value == spelling
        );
    }
    if op == Tok.STAR_POW {
        return self._python_operation(
            "power", [left, right], [ir.Constant(ir.IntType(64), int(inplace))]
        );
    }
    operations: dict[str, str] = {
        Tok.PLUS: "add",
        Tok.MINUS: "sub",
        Tok.STAR_MUL: "mul",
        Tok.DIV: "truediv",
        Tok.FLOOR_DIV: "floordiv",
        Tok.MOD: "mod",
        Tok.LSHIFT: "lshift",
        Tok.RSHIFT: "rshift",
        Tok.BW_AND: "and_",
        Tok.BW_OR: "or_",
        Tok.BW_XOR: "xor"
    };
    operation = operations[op];
    if inplace {
        operation = "i" + operation.rstrip("_");
    }
    return self._python_operation(operation, [left, right], []);
}

impl NaIRGenPass._python_compare(
    op: str, left: ir.Value, right: ir.Value, consume: bool
) -> ir.Value {
    if op in (Tok.KW_IS, Tok.KW_ISN) {
        lbox = self._python_box(left, consume=False);
        rbox = self._python_box(right, consume=False);
        result = self.builder.icmp_unsigned(
            "!=" if op == Tok.KW_ISN else "==",
            self._python_handle(lbox),
            self._python_handle(rbox)
        );
        self._release_owned_args(
            [
                value
                for (original, value) in [(left, lbox), (right, rbox)]
                if value is not original
            ]
        );
        if consume {
            self._release_owned_args([left, right]);
        }
        return result;
    }
    if op in (Tok.KW_IN, Tok.KW_NIN) {
        raw = self._python_operation(
            "contains", [right, left], [], status=True, consume=consume
        );
        return self.builder.icmp_signed(
            "==" if op == Tok.KW_NIN else "!=", raw, ir.Constant(ir.IntType(64), 0)
        );
    }
    operations = {Tok.LT: 0, Tok.LTE: 1, Tok.EE: 2, Tok.NE: 3, Tok.GT: 4, Tok.GTE: 5};
    return self._python_operation(
        "compare",
        [left, right],
        [ir.Constant(ir.IntType(64), operations[op])],
        consume=consume
    );
}

impl NaIRGenPass._python_compare_chain(
    nd: uni.CompareExpr, left: ir.Value
) -> ir.Value {
    function = self.builder.function;
    done = function.append_basic_block("python.compare.done");
    incoming: list[tuple[ir.Value, ir.Block]] = [];
    current = left;
    for (index, token) in enumerate(nd.ops) {
        right = self._codegen_required(nd.rights[index]);
        assert right is not None;
        operation = token.name if isinstance(token, uni.Token) else str(token);
        result = self._python_box(
            self._python_compare(operation, current, right, False)
        );
        self._release_owned_args([current]);
        if index == len(nd.ops) - 1 {
            self._release_owned_args([right]);
            self._consume_temporary(result);
            incoming.append((result, self.builder.block));
            self.builder.branch(done);
        } else {
            truth = self._to_bool(result);
            next_link = function.append_basic_block("python.compare.next");
            stop = function.append_basic_block("python.compare.stop");
            self.builder.cbranch(truth, next_link, stop);
            self.builder.position_at_end(stop);
            self._release_owned_args([right]);
            self._consume_temporary(result);
            incoming.append((result, self.builder.block));
            self.builder.branch(done);
            self.builder.position_at_end(next_link);
            self._release_owned_args([result]);
            current = right;
        }
    }
    self.builder.position_at_end(done);
    value = self.builder.phi(self.struct_types["__JacPythonValue"].as_pointer());
    for (result, block) in incoming {
        value.add_incoming(result, block);
    }
    self._mark_reference_owned(value);
    self._protect_temporary(value);
    return value;
}

impl NaIRGenPass._python_bool_expr(nd: uni.BoolExpr, first: ir.Value) -> ir.Value {
    function = self.builder.function;
    done = function.append_basic_block("python.bool.done");
    incoming: list[tuple[ir.Value, ir.Block]] = [];
    operation = nd.op.name if isinstance(nd.op, uni.Token) else str(nd.op);
    value = self._python_box(first);
    for index in range(len(nd.values)) {
        if not self._is_owned(value) {
            self._emit_take_ref(value, op="python.bool.keep");
            self._mark_owned(value);
            self._protect_temporary(value);
        }
        if index == len(nd.values) - 1 {
            self._consume_temporary(value);
            incoming.append((value, self.builder.block));
            self.builder.branch(done);
        } else {
            truth = self._to_bool(value);
            next_value = function.append_basic_block("python.bool.next");
            keep = function.append_basic_block("python.bool.keep");
            self.builder.cbranch(
                truth,
                next_value if operation == Tok.KW_AND else keep,
                keep if operation == Tok.KW_AND else next_value
            );
            self.builder.position_at_end(keep);
            self._consume_temporary(value);
            incoming.append((value, self.builder.block));
            self.builder.branch(done);
            self.builder.position_at_end(next_value);
            self._release_owned_args([value]);
            raw = self._codegen_required(nd.values[index + 1]);
            assert raw is not None;
            value = self._python_box(raw);
        }
    }
    self.builder.position_at_end(done);
    result = self.builder.phi(self.struct_types["__JacPythonValue"].as_pointer());
    for (value, block) in incoming {
        result.add_incoming(value, block);
    }
    self._mark_reference_owned(result);
    self._protect_temporary(result);
    return result;
}

import jaclang.compiler.backends.native.llvm.ir.values as values;
import jaclang.compiler.backends.native.llvm.ir.types as types;
import jaclang.compiler.backends.native.llvm.ir._utils as _utils;
import from jaclang.compiler.backends.native.llvm.ir.context { Context, global_context }

"""The cache key of one metadata operand: equal operands share a key.

Constants compare by their text and metadata strings by their string; every
other value (a metadata node is already unique per module) is itself."""
def _operand_key(op: values.Value) -> str {
    if isinstance(op, values.Constant) {
        text = str(op);
        return f"C{len(text)}:{text}";
    }
    if isinstance(op, values.MetaDataString) {
        return f"S{len(op.string)}:{op.string}";
    }
    return f"I{id(op)}:";
}

"""The cache key of one debug-info operand value."""
def _di_value_key(name: str, value: any) -> str {
    if value is None {
        return "N:";
    }
    if isinstance(value, bool) {
        return "n1:" if value else "n0:";
    }
    if isinstance(value, int) {
        return f"n{value}:";
    }
    if isinstance(value, str) {
        return f"s{len(value)}:{value}";
    }
    if isinstance(value, values.DIToken) {
        if name == 'encoding' {
            return f"s{len(value.value)}:{value.value}";
        }
        return f"T{id(value)}:";
    }
    if isinstance(value, values.Value) {
        return _operand_key(value);
    }
    return f"O{id(value)}:";
}

class Module {
    has context: Context,
        name: str = '',
        data_layout: str = "",
        scope: _utils.NameScope,
        triple: str = 'unknown-unknown-unknown',
        globals: dict[str, values.GlobalValue],
        metadata: list[values.NamedValue],
        namedmetadata: dict[str, values.NamedMetaData],
        _metadatacache: dict[str, values.MDValue],
        _debuginfocache: dict[str, values.DIValue];

    def init(self: Module, name: str = '', context: Context | None = None) {
        self.context = context if context is not None else global_context;
        self.name = name;
        self.data_layout = "";
        self.scope = _utils.NameScope();
        self.triple = 'unknown-unknown-unknown';
        self.globals = {};
        self.metadata = [];
        self.namedmetadata = {};
        self._metadatacache = {};
        self._debuginfocache = {};
    }

    def _fix_metadata_operands(self: Module, operands: any) -> list[values.Value] {
        fixed_ops: list[values.Value] = [];
        if not isinstance(operands, (`list, `tuple)) {
            return fixed_ops;
        }
        for raw_op in operands {
            if (raw_op is None) {
                fixed_ops.append(values.Constant(types.MetaDataType(), None));
            } elif isinstance(raw_op, str) {
                fixed_ops.append(values.MetaDataString(self, raw_op));
            } elif isinstance(raw_op, (`list, `tuple)) {
                fixed_ops.append(self.add_metadata(raw_op));
            } elif isinstance(raw_op, values.Value) {
                fixed_ops.append(raw_op);
            } else {
                raise TypeError(f"not a metadata operand: {raw_op!r}");
            }
        }
        return fixed_ops;
    }

    """
        Add an unnamed metadata to the module with the given *operands*
        (a sequence of values) or return a previous equivalent metadata.
        A MDValue instance is returned, it can then be associated to
        e.g. an instruction.
        """
    def add_metadata(self: Module, operands: any) -> values.MDValue {
        if not isinstance(operands, (`list, `tuple)) {
            raise TypeError(
                f"expected a list or tuple of metadata values, got {operands!r}"
            );
        }
        fixed = self._fix_metadata_operands(operands);
        key = "".join([_operand_key(op) for op in fixed]);
        md = self._metadatacache.get(key);
        if md is None {
            n = len(self.metadata);
            md = values.MDValue(self, fixed, str(n));
            self._metadatacache[key] = md;
        }
        return md;
    }

    """
        Add debug information metadata to the module with the given
        *operands* (a dict of values with string keys) or return
        a previous equivalent metadata.  *kind* is a string of the
        debug information kind (e.g. "DICompileUnit").

        A DIValue instance is returned, it can then be associated to e.g.
        an instruction.
        """
    def add_debug_info(
        self: Module, kind: str, operands: dict[str, any], is_distinct: bool = False
    ) -> values.DIValue {
        nodes: dict[str, values.MDValue] = {};
        for (name, op) in operands.items() {
            if isinstance(op, (`list, `tuple)) {
                nodes[name] = self.add_metadata(op);
            }
        }
        fixed: list[values.DIOperand] = [];
        parts: list[str] = [f"{len(kind)}:{kind}", "d1" if is_distinct else "d0"];
        for name in sorted(operands.keys()) {
            op = operands[name];
            made = nodes.get(name);
            if made is not None {
                fixed.append(values.DIOperand(name, made));
                parts.append(f"{len(name)}:{name}={_operand_key(made)}");
            } else {
                fixed.append(values.DIOperand(name, op));
                parts.append(f"{len(name)}:{name}={_di_value_key(name, op)}");
            }
        }
        key = "".join(parts);
        di = self._debuginfocache.get(key);
        if di is None {
            n = len(self.metadata);
            di = values.DIValue(self, is_distinct, kind, fixed, str(n));
            self._debuginfocache[key] = di;
        }
        return di;
    }

    """
        Add a named metadata node to the module, if it doesn't exist,
        or return the existing node.
        If *element* is given, it will append a new element to
        the named metadata node.  If *element* is a sequence of values
        (rather than a metadata value), a new unnamed node will first be
        created.

        Example::
            module.add_named_metadata("llvm.ident", ["jaclang.compiler.backends.native.llvm/1.0"])
        """
    def add_named_metadata(
        self: Module, name: str, element: any = None
    ) -> values.NamedMetaData {
        nmd = self.namedmetadata.get(name);
        if nmd is None {
            nmd = values.NamedMetaData(self);
            self.namedmetadata[name] = nmd;
        }
        if (element is not None) {
            if isinstance(element, values.Value) {
                if not isinstance(element.type, types.MetaDataType) {
                    raise TypeError(
                        "wrong type for metadata element: got " + element.__repr__()
                    );
                }
                nmd.add(element);
            } else {
                nmd.add(self.add_metadata(element));
            }
        }
        return nmd;
    }

    """
        A list of functions declared or defined in this module.
        """
    has functions: list[values.Function] {
        getter {
            found: list[values.Function] = [];
            for v in self.globals.values() {
                if isinstance(v, values.Function) {
                    found.append(v);
                }
            }
            return found;
        }
    }

    """
        The global values in this module.
        """
    has global_values: list[values.GlobalValue] {
        getter {
            return [v for v in self.globals.values()];
        }
    }

    """
        Get a global value by name.
        """
    def get_global(self: Module, name: str) -> values.GlobalValue {
        return self.globals[name];
    }

    """
        Add a new global value.
        """
    def add_global(self: Module, globalvalue: values.GlobalValue) {
        assert (globalvalue.name not in self.globals);
        self.globals[globalvalue.name] = globalvalue;
    }

    def get_identified_types(self: Module) -> dict[str, types.IdentifiedStructType] {
        return self.context.identified_types;
    }

    def _get_body_lines(self: Module) -> list[str] {
        lines = [it.get_declaration() for it in self.get_identified_types().values()];
        for v in self.globals.values() {
            lines.append(str(v));
        }
        return lines;
    }

    def _get_metadata_lines(self: Module) -> list[str] {
        mdbuf: list[str] = [];
        for (k, v) in self.namedmetadata.items() {
            operands = ', '.join([i.get_reference() for i in v.operands]);
            mdbuf.append("!" + k + " = !{ " + operands + " }");
        }
        for md in self.metadata {
            mdbuf.append(str(md));
        }
        return mdbuf;
    }

    def _stringify_body(self: Module) -> str {
        return "\n".join(self._get_body_lines());
    }

    def _stringify_metadata(self: Module) -> str {
        return "\n".join(self._get_metadata_lines());
    }

    def __repr__(self: Module) -> str {
        lines: list[str] = [
            '; ModuleID = "' + self.name + '"',
            'target triple = "' + self.triple + '"',
            'target datalayout = "' + self.data_layout + '"',
            ''
        ];
        lines += self._get_body_lines();
        lines += self._get_metadata_lines();
        return "\n".join(lines);
    }

    def __str__(self: Module) -> str {
        return self.__repr__();
    }
}

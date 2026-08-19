"""Graph schema extraction.

Derives the relational shape of a module's graph from what the program
already declares: node/edge/obj archetypes with typed `has` fields, declared
edge endpoints (`edge E: Src -> Tgt`), and — for edges declared without
endpoints — the endpoint types observed at every connect site (`ConnectOp`).

The result is written to `ir_in.gen.interop_manifest.graph_schema` as a
plain JSON-serializable dict so it travels with the compiled module and the
.jir cache, and can be consumed by the store (DDL derivation) and the query
planner (join maps, untyped-hop pruning).

Endpoint inference is best-effort by design: an operand whose static type
cannot be resolved records `None` (an open endpoint). Consumers must treat
an edge with any open observation as connecting unknown node types — this
degrades planning, never correctness.
"""

import from jaclang.jac0core.unitree {
    Ability,
    Archetype,
    AstSymbolNode,
    AtomTrailer,
    AtomUnit,
    BinaryExpr,
    ConnectOp,
    EventSignature,
    Expr,
    FuncCall,
    HasVar,
    IndexSlice,
    Name,
    Null,
    SpecialVarRef,
    Token,
    UniNode
}
import from jaclang.jac0core.constant { EdgeDir, SymbolType, Tokens as Tok }
import from jaclang.jac0core.passes.uni_pass { UniPass }

glob SCALAR_SQL: dict[str, str] = {
         'str': 'text',
         'int': 'bigint',
         'float': 'double precision',
         'bool': 'boolean',
         'bytes': 'bytea',
         'UUID': 'uuid',
         'datetime': 'timestamptz',
         'date': 'date',
         'time': 'time',
         'timedelta': 'interval',
         'Decimal': 'numeric'
     },
     GENERIC_EDGE = 'GenericEdge',
     ROOT_NODE = 'Root';


class GraphSchemaPass(UniPass) {
    def before_pass(self: GraphSchemaPass) {
        self._nodes: dict[str, dict] = {};
        self._edges: dict[str, dict] = {};
        self._objs: dict[str, dict] = {};
    }

    def enter_archetype(self: GraphSchemaPass, nd: Archetype) -> None {
        # arch_kind is None for obj/class archetypes, so key off the token
        kind = nd.arch_type.name;
        if kind not in [Tok.KW_NODE, Tok.KW_EDGE, Tok.KW_OBJECT, Tok.KW_CLASS] {
            return;
        }
        if not isinstance(nd.name, Name) {
            return;
        }
        spec = {
            'module': self.ir_in.name,
            'bases': self._base_names(nd),
            'fields': [self._field_spec(hv) for hv in nd.get_has_vars()]
        };
        if kind == Tok.KW_NODE {
            self._nodes[nd.name.sym_name] = spec;
        } elif kind == Tok.KW_EDGE {
            spec['declared'] = self._declared_endpoints(nd);
            spec['observed'] = [];
            spec['undirected_seen'] = False;
            self._edges[nd.name.sym_name] = spec;
        } else {
            fields = spec['fields'];
            spec['flat_scalar'] = bool(fields)
                and all(f['tier'] in ['scalar', 'enum'] for f in fields);
            self._objs[nd.name.sym_name] = spec;
        }
    }

    def enter_binary_expr(self: GraphSchemaPass, nd: BinaryExpr) -> None {
        if not isinstance(nd.op, ConnectOp) {
            return;
        }
        edge_name = GENERIC_EDGE;
        conn = nd.op.conn_type;
        if conn is not None {
            named = self._expr_type_name(conn);
            if named {
                edge_name = named;
            }
        }
        entry = self._edges.get(edge_name);
        if entry is None {
            entry = {
                'module': self.ir_in.name,
                'bases': [],
                'fields': [],
                'declared': None,
                'observed': [],
                'undirected_seen': False
            };
            self._edges[edge_name] = entry;
        }
        left = self._node_type_of(nd.left);
        right = self._node_type_of(nd.right);
        if nd.op.edge_dir == EdgeDir.IN {
            (src, dst) = (right, left);
        } else {
            (src, dst) = (left, right);
        }
        if nd.op.edge_dir == EdgeDir.ANY {
            entry['undirected_seen'] = True;
        }
        pair = [src, dst];
        if pair not in entry['observed'] {
            entry['observed'].append(pair);
        }
    }

    def after_pass(self: GraphSchemaPass) {
        if not (self._nodes or self._edges or self._objs) {
            return;
        }
        self.ir_in.gen.interop_manifest.graph_schema = {
            'version': 1,
            'module': self.ir_in.name,
            'nodes': self._nodes,
            'edges': self._edges,
            'objs': self._objs
        };
    }

    # ------------------------------------------------------------------
    # declaration side

    def _base_names(self: GraphSchemaPass, nd: Archetype) -> list[str] {
        out: list[str] = [];
        for b in (nd.base_classes or []) {
            named = self._expr_type_name(b);
            if named {
                out.append(named);
            }
        }
        return out;
    }

    def _declared_endpoints(self: GraphSchemaPass, nd: Archetype) -> (dict | None) {
        if nd.src_endpoint is None and nd.tgt_endpoint is None {
            return None;
        }
        return {
            'src': self._expr_type_name(nd.src_endpoint),
            'dst': self._expr_type_name(nd.tgt_endpoint)
        };
    }

    def _field_spec(self: GraphSchemaPass, hv: HasVar) -> dict {
        ann = hv.type_tag.tag if hv.type_tag else None;
        info = self._classify_type(ann);
        info['name'] = hv.name.sym_name;
        info['has_default'] = hv.value is not None or hv.defer;
        return info;
    }

    # Classify a type annotation into a storage tier:
    #   scalar        -> typed column (SCALAR_SQL)
    #   enum          -> text column
    #   node_ref      -> uuid FK column into the node directory
    #   node_ref_list -> uuid[] column
    #   obj           -> flattenable side-table candidate (jsonb otherwise)
    #   json          -> jsonb column (dicts, unions, unresolved, `any`)
    def _classify_type(self: GraphSchemaPass, ann: (Expr | None)) -> dict {
        out = {'tier': 'json', 'type': 'any', 'target': None, 'optional': False};
        while isinstance(ann, AtomUnit) {
            ann = ann.value;
        }
        if ann is None or not isinstance(ann, Expr) {
            return out;
        }
        # unwrap (X | None) into optional X; wider unions stay json
        if isinstance(ann, BinaryExpr)
            and isinstance(ann.op, Token)
            and ann.op.name == Tok.BW_OR {
            parts = self._union_parts(ann);
            non_null = [
                p
                for p in parts
                if not self._is_null_expr(p)
            ];
            if len(non_null) == 1 and len(parts) > len(non_null) {
                inner = self._classify_type(non_null[0]);
                inner['optional'] = True;
                return inner;
            }
            out['type'] = 'union';
            return out;
        }
        if isinstance(ann, AtomTrailer) {
            return self._classify_subscript(ann, out);
        }
        named = self._expr_type_name(ann);
        if not named {
            return out;
        }
        out['type'] = named;
        if named in SCALAR_SQL {
            out['tier'] = 'scalar';
            return out;
        }
        if named == 'None' {
            out['optional'] = True;
            return out;
        }
        sym = self._resolve_symbol(ann);
        if sym is None {
            return out;
        }
        if sym.sym_type == SymbolType.NODE_ARCH {
            out['tier'] = 'node_ref';
            out['target'] = named;
        } elif sym.sym_type == SymbolType.EDGE_ARCH {
            out['tier'] = 'edge_ref';
            out['target'] = named;
        } elif sym.sym_type == SymbolType.ENUM_ARCH {
            out['tier'] = 'enum';
            out['target'] = named;
        } elif sym.sym_type == SymbolType.OBJECT_ARCH {
            out['tier'] = 'obj';
            out['target'] = named;
        }
        return out;
    }

    def _classify_subscript(
        self: GraphSchemaPass, ann: AtomTrailer, out: dict
    ) -> dict {
        base = self._expr_type_name(ann.target);
        if not base or not isinstance(ann.right, IndexSlice) {
            return out;
        }
        out['type'] = base;
        if base not in ['list', 'set'] {
            return out;
        }
        slices = ann.right.slices;
        if len(slices) != 1 or slices[0].start is None {
            return out;
        }
        elem = self._classify_type(slices[0].start);
        if elem['tier'] == 'node_ref' {
            out['tier'] = 'node_ref_list';
            out['target'] = elem['target'];
        } elif elem['tier'] == 'scalar' {
            out['tier'] = 'scalar_list';
            out['type'] = f"{base}[{elem['type']}]";
        } elif elem['tier'] == 'obj' {
            out['tier'] = 'obj_list';
            out['target'] = elem['target'];
        }
        return out;
    }

    def _is_null_expr(self: GraphSchemaPass, nd: Expr) -> bool {
        if isinstance(nd, Null) {
            return True;
        }
        return isinstance(nd, Name) and nd.sym_name == 'None';
    }

    def _union_parts(self: GraphSchemaPass, nd: Expr) -> list[Expr] {
        if isinstance(nd, BinaryExpr)
            and isinstance(nd.op, Token)
            and nd.op.name == Tok.BW_OR {
            return self._union_parts(nd.left) + self._union_parts(nd.right);
        }
        return [nd];
    }

    # ------------------------------------------------------------------
    # connect-site side

    def _node_type_of(self: GraphSchemaPass, operand: (Expr | None)) -> (str | None) {
        if operand is None {
            return None;
        }
        # chained connect: the value of `a ++> b` is its target side
        if isinstance(operand, BinaryExpr) and isinstance(operand.op, ConnectOp) {
            return self._node_type_of(operand.right);
        }
        if isinstance(operand, FuncCall) {
            sym = self._resolve_symbol(operand.target);
            if sym and sym.sym_type == SymbolType.NODE_ARCH {
                return sym.sym_name;
            }
            return None;
        }
        if isinstance(operand, SpecialVarRef) {
            if operand.sym_name == 'root' {
                return ROOT_NODE;
            }
            if operand.sym_name == 'self' {
                arch = self._enclosing_archetype(operand);
                if arch and arch.arch_kind == 'node' and isinstance(arch.name, Name) {
                    return arch.name.sym_name;
                }
                return None;
            }
            if operand.sym_name == 'here' {
                return self._here_type(operand);
            }
            return None;
        }
        if isinstance(operand, Name) {
            sym = self._resolve_symbol(operand);
            if sym and sym.sym_type == SymbolType.NODE_ARCH {
                return sym.sym_name;
            }
        }
        return None;
    }

    def _here_type(self: GraphSchemaPass, nd: UniNode) -> (str | None) {
        cursor = nd.parent;
        while cursor is not None and not isinstance(cursor, Ability) {
            cursor = cursor.parent;
        }
        if cursor is None {
            return None;
        }
        sig = cursor.signature;
        if isinstance(sig, EventSignature) and isinstance(sig.arch_tag_info, Name) {
            named = sig.arch_tag_info.sym_name;
            return ROOT_NODE if named == 'root' else named;
        }
        return None;
    }

    def _enclosing_archetype(self: GraphSchemaPass, nd: UniNode) -> (Archetype | None) {
        cursor = nd.parent;
        while cursor is not None and not isinstance(cursor, Archetype) {
            cursor = cursor.parent;
        }
        return cursor;
    }

    # ------------------------------------------------------------------
    # shared helpers

    def _expr_type_name(self: GraphSchemaPass, e: (Expr | None)) -> (str | None) {
        if e is None {
            return None;
        }
        if isinstance(e, Name) {
            return e.sym_name;
        }
        if isinstance(e, FuncCall) {
            return self._expr_type_name(e.target);
        }
        if isinstance(e, AtomTrailer) {
            attrs = e.as_attr_list;
            if attrs {
                last = attrs[-1];
                if isinstance(last, AstSymbolNode) {
                    return last.sym_name;
                }
            }
        }
        return None;
    }

    def _resolve_symbol(self: GraphSchemaPass, e: (Expr | None)) -> (object | None) {
        if isinstance(e, Name) {
            sym = e.sym;
            if not sym and e.sym_tab {
                sym = e.sym_tab.lookup(e.sym_name, deep=True);
            }
            return sym;
        }
        if isinstance(e, AtomTrailer) {
            attrs = e.as_attr_list;
            if attrs {
                last = attrs[-1];
                if isinstance(last, AstSymbolNode) and last.sym {
                    return last.sym;
                }
            }
        }
        return None;
    }
}

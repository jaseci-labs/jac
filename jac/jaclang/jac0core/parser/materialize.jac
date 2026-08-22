import ctypes;
import sys;

import jaclang.jac0core.constant as _mat_constant;
import jaclang.jac0core.parser.parser as _mat_parser;
import jaclang.jac0core.parser.tokens as _mat_tokens;
import jaclang.jac0core.srcloc as _mat_srcloc;
import jaclang.jac0core.unitree as uni;

glob MATERIALIZE_FIXUPS: tuple = (
         ("symbol-stub-replay", 8142),
         ("name-spec-rebinding", 8143),

     ),
     _SYM_REBIND: dict[str, str] = {
         "ParamVar": "VAR",
         "HasVar": "HAS_VAR",
         "TypeParam": "TYPE",
         "TypeAlias": "TYPE",
         "SemDef": "SEM",
         "ImplDef": "IMPL",
         "Test": "TEST"
     };

def materialize_fixups(module: any) {
    stack: list = [module];
    visited: set = set();
    nodes: list = [];
    while stack {
        cur = stack.pop();
        if id(cur) in visited {
            continue;
        }
        visited.add(id(cur));
        nodes.append(cur);
        for k in (cur?.kid or []) {
            if k is not None {
                stack.append(k);
            }
        }
    }
    for nd in nodes {
        if isinstance(nd, uni.Name) {
            if nd.__dict__.get("name_spec") is not nd {
                nd.name_spec = nd;
            }
            continue;
        }

        if isinstance(nd, uni.AstSymbolStubNode)
            and nd.__dict__.get("name_spec") is None {
            st = type(nd)?.SYMBOL_TYPE;
            if st is not None {
                getattr(uni.AstSymbolStubNode, "_init_stub")(nd, st);
            } else {
                nd.__post_init__();
            }
            continue;
        }

        rebind = _SYM_REBIND.get(type(nd).__name__);
        if rebind is not None {
            spec = nd.__dict__.get("name_spec");
            if spec is not None and spec is not nd {
                name_child = nd.__dict__.get("name");
                sym_name = str(name_child?.value or getattr(spec, "value", ""));
                if rebind == "TEST" {
                    desc_child = nd.__dict__.get("description");
                    if desc_child is not None and name_child is not None {
                        ident = _mat_parser._test_ident_from_desc(
                            _mat_parser._string_lit_text(
                                str(getattr(desc_child, "value", ""))
                            )
                        );
                        if ident {
                            name_child.value = ident;
                            sym_name = ident;
                        }
                    }
                    if not sym_name.startswith("test_") {
                        sym_name = f"test_{sym_name}";
                    }
                }
                getattr(uni.AstSymbolNode, "_init_symbol")(
                    nd,
                    sym_name=sym_name,
                    name_spec=spec,
                    sym_category=getattr(uni.SymbolType, rebind)
                );
            }
        }
    }
}

def _bind_error(lib_path: str, reason: str) -> RuntimeError {
    return RuntimeError(
        f"sealed parser artifact could not be bound ({lib_path}): {reason}. "
        "Reinstall or rebuild this jac payload."
    );
}

def _native_str_args(str_new: any, param_types: list, args: tuple) -> list {
    c_args: list = [];
    ai = 0;
    for pt in param_types {
        if pt in ("jacstr3", "jacstr2") {
            b = args[ai].encode("utf-8");
            ai += 1;
            sp = str_new(b, len(b));
            if pt == "jacstr3" {
                c_args.extend([sp, sp, len(b)]);
            } else {
                c_args.extend([sp, len(b)]);
            }
        } else {
            c_args.append(args[ai]);
            ai += 1;
        }
    }
    return c_args;
}

def _entry_argtypes(param_types: list) -> list {
    out: list = [];
    for pt in param_types {
        if pt == "jacstr3" {
            out.extend([ctypes.c_void_p, ctypes.c_void_p, ctypes.c_int64]);
        } elif pt == "jacstr2" {
            out.extend([ctypes.c_void_p, ctypes.c_int64]);
        } else {
            out.append(ctypes.c_int64);
        }
    }
    return out;
}

obj NativeParser {
    has lib_path: str,
        _engine: any = None,
        _str_new: any = None,
        _parse: any = None,
        _parse_types: list = [],
        _diags: any = None,
        _diags_types: list = [],
        _merge: any = None,
        _merge_types: list = [],
        _prefix: any = None,
        _prefix_types: list = [],
        _pydec: any = None,
        _keep: list = [];

    def _call(fn: any, param_types: list, args: tuple) -> any {
        c_args = _native_str_args(self._str_new, param_types, args);
        h = fn(*c_args);
        if not h {
            raise _bind_error(
                self.lib_path,
                f"the crossing entry returned NULL on {args[-1]}; the "
                "artifact and this runtime disagree"
            );
        }
        out = ctypes.cast(h, ctypes.py_object).value;
        self._pydec(out);
        return out;
    }

    def parse(src: str, path: str) -> tuple {
        r = self._call(self._parse, self._parse_types, (src, path, ));
        materialize_fixups(r[0]);
        return (r[0], r[1], r[2], r[3], r[4], r[5], );
    }

    def parse_diags(src: str, path: str) -> tuple {
        r = self._call(self._diags, self._diags_types, (src, path, ));
        return (r[0], r[1], r[2], r[3], );
    }

    def merge_probe(src: str, path: str, annex_src: str, annex_path: str) -> tuple {
        r = self._call(
            self._merge, self._merge_types, (src, path, annex_src, annex_path, )
        );
        materialize_fixups(r[0]);
        return (r[0], r[1], r[2], );
    }

    def serves_prefix -> bool {
        return self._prefix is not None;
    }

    def parse_and_run_prefix(
        src: str,
        path: str,
        claimed_n: int,
        project_root: str,
        has_project_root: int,
        access_enforced: int
    ) -> tuple {
        r = self._call(
            self._prefix,
            self._prefix_types,
            (src, path, claimed_n, project_root, has_project_root, access_enforced, )
        );
        materialize_fixups(r[0]);
        return (r[0], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9], );
    }
}

def bind_native_parser(lib_path: str, layout_dict: dict) -> NativeParser {
    import from jaclang.jac0core.native_dylib { DylibEngine, layout_from_dict }

    eng = DylibEngine(lib_path);
    eng.initialize();
    layout = layout_from_dict(layout_dict);

    str_new_addr = 0;
    for sn_name in ("jac_str_new", "__jac_str_new") {
        str_new_addr = eng.get_function_address(sn_name);
        if str_new_addr {
            break;
        }
    }
    if not str_new_addr {
        raise _bind_error(lib_path, "jac_str_new is not exported");
    }
    str_new = ctypes.CFUNCTYPE(ctypes.c_void_p, ctypes.c_char_p, ctypes.c_int64)(
        str_new_addr
    );

    entries: dict = {};
    for entry_name in ("mat_parse", "mat_parse_diags", "mat_merge_probe") {
        fl = layout.functions.get(entry_name);
        if fl is None {
            raise _bind_error(lib_path, f"layout exports no {entry_name}");
        }
        addr = eng.get_function_address(entry_name);
        if not addr {
            raise _bind_error(lib_path, f"{entry_name} did not link");
        }
        entries[entry_name] = (
            ctypes.PYFUNCTYPE(ctypes.c_uint64, *_entry_argtypes(fl.param_types))(addr),
            list(fl.param_types),

        );
    }
    prefix_fn: any = None;
    prefix_types: list = [];
    prefix_fl = layout.functions.get("mat_parse_and_run_prefix");
    if prefix_fl is not None {
        prefix_addr = eng.get_function_address("mat_parse_and_run_prefix");
        if not prefix_addr {
            raise _bind_error(
                lib_path,
                "the layout exports mat_parse_and_run_prefix but the "
                "artifact does not link it"
            );
        }
        prefix_fn = ctypes.PYFUNCTYPE(
            ctypes.c_uint64, *_entry_argtypes(prefix_fl.param_types)
        )(
            prefix_addr
        );
        prefix_types = list(prefix_fl.param_types);
    }

    cdll = eng._cdll;
    i64 = ctypes.c_int64;
    mat_reset = ctypes.PYFUNCTYPE(None, i64, i64, i64)(("mat_reset", cdll, ));
    mat_set_class = ctypes.PYFUNCTYPE(None, i64, i64, i64)(("mat_set_class", cdll, ));
    mat_set_key = ctypes.PYFUNCTYPE(None, i64, i64)(("mat_set_key", cdll, ));
    mat_set_enum = ctypes.PYFUNCTYPE(None, i64, i64)(("mat_set_enum", cdll, ));
    pydec = ctypes.pythonapi.Py_DecRef;
    setattr(pydec, "argtypes", [ctypes.py_object]);

    manifest = layout_dict.get("materialize_manifest");
    if not manifest {
        raise _bind_error(
            lib_path, "artifact carries no materializer manifest; rebuild the payload"
        );
    }
    class_ns = (
        _mat_parser.__dict__,
        uni.__dict__,
        _mat_srcloc.__dict__,
        _mat_tokens.__dict__,

    );
    enum_ns = (uni, _mat_constant, _mat_srcloc, _mat_tokens);
    keep: list = [];
    enum_handles: list = [];
    for em_pair in manifest["enums"] {
        (mat_en, mat_members) = em_pair;
        ecls: any = None;
        for ns_mod in enum_ns {
            ecls = getattr(ns_mod, mat_en, None);
            if ecls is not None {
                break;
            }
        }
        if ecls is None {
            raise _bind_error(lib_path, f"manifest names unknown enum {mat_en}");
        }
        for mn in mat_members {
            enum_handles.append(getattr(ecls, mn));
        }
    }
    mat_reset(
        len(manifest["class_names"]), len(manifest["key_names"]), len(enum_handles)
    );
    for (mat_ci, mat_cn) in enumerate(manifest["class_names"]) {
        mat_cls: any = None;
        for ns in class_ns {
            mat_cls = ns.get(mat_cn);
            if mat_cls is not None {
                break;
            }
        }
        if mat_cls is None {
            raise _bind_error(lib_path, f"manifest names unknown class {mat_cn}");
        }
        mat_new = mat_cls.__new__;
        keep.append(mat_new);
        mat_set_class(mat_ci, id(mat_cls), id(mat_new));
    }
    for (mat_ki, mat_kn) in enumerate(manifest["key_names"]) {
        mat_key = sys.intern(mat_kn);
        keep.append(mat_key);
        mat_set_key(mat_ki, id(mat_key));
    }
    for (mat_ei, mat_mh) in enumerate(enum_handles) {
        keep.append(mat_mh);
        mat_set_enum(mat_ei, id(mat_mh));
    }
    keep.extend([str_new, mat_reset, mat_set_class, mat_set_key, mat_set_enum]);

    (parse_fn, parse_types) = entries["mat_parse"];
    (diags_fn, diags_types) = entries["mat_parse_diags"];
    (merge_fn, merge_types) = entries["mat_merge_probe"];
    return NativeParser(
        lib_path=lib_path,
        _engine=eng,
        _str_new=str_new,
        _parse=parse_fn,
        _parse_types=parse_types,
        _diags=diags_fn,
        _diags_types=diags_types,
        _merge=merge_fn,
        _merge_types=merge_types,
        _prefix=prefix_fn,
        _prefix_types=prefix_types,
        _pydec=pydec,
        _keep=keep
    );
}

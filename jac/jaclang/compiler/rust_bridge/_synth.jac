import from jaclang.compiler.rust_bridge._blob {
    FN_CTOR,
    FN_METHOD,
    KIND_ERROR,
    KIND_OPAQUE,
    TAG_BOOL,
    TAG_FN,
    TAG_OPT_BIT,
    TAG_REF_BIT,
    TAG_STR,
    TAG_VOID
}


class Skip {
    def init(self: Skip, item: str, reason: str) {
        self.item = item;
        self.reason = reason;
    }
}


class NaModule {
    def init(self: NaModule, source: str, skips: list = None, bridged: int = 0) {
        self.source = source;
        self.skips = skips if skips is not None else [];
        self.bridged = bridged;
    }
}


def _base(tag: int) -> int {
    return tag & ~TAG_OPT_BIT;
}


def _is_opt(tag: int) -> bool {
    return bool(tag & TAG_OPT_BIT);
}


def _is_ref(tag: int) -> bool {
    base = _base(tag);
    return bool(base & TAG_REF_BIT) and base != TAG_VOID;
}


def _ref_index(tag: int) -> int {
    return _base(tag) & ~TAG_REF_BIT;
}


def _drop_sym_for(meta: object, kind: int) -> object {
    for td in meta.types {
        if td.kind == kind and td.drop_sym {
            return td.drop_sym;
        }
    }
    return None;
}


class _Synth {
    def init(self: _Synth, meta: object, so_basename: str) {
        self.meta = meta;
        self.so = so_basename;
        self.skips = [];
        self.opaque = {
            td.index: td.name
            for td in meta.types
            if td.kind == KIND_OPAQUE
        };
        ctor_targets = {
            _ref_index(fd.ret)
            for fd in meta.fns
            if fd.kind == FN_CTOR
            and _is_ref(fd.ret)
            and _ref_index(fd.ret) in self.opaque
        };
        self.adoptable = {
            _ref_index(fd.ret)
            for fd in meta.fns
            if fd.kind == FN_METHOD
            and _is_ref(fd.ret)
            and _ref_index(fd.ret) in self.opaque
            and _ref_index(fd.ret) not in ctor_targets
        };
        self.error_drop = _drop_sym_for(meta, KIND_ERROR);
        self.error_msg_sym = None;
        for fd in meta.fns {
            if fd.name == "message"
            and fd.ret == TAG_STR
            and fd.self_type != TAG_VOID
            and fd.self_type < len(meta.types)
            and meta.types[fd.self_type].kind == KIND_ERROR {
                self.error_msg_sym = fd.sym;
                break;
            }
        }
        self.free_buf = f"jac_{meta.module_name}_free_buf";
        self.make_buf_sym = f"jac_{meta.module_name}_make_buf";
        self._bridged_str_method = False;
        self._bridged_callback = False;
    }

    def _shim_decl(self: _Synth, fd: object) -> object {
        params = [];
        if fd.kind == FN_METHOD and fd.self_type != TAG_VOID {
            params.append("handle: int");
        }
        for p in fd.params {
            if p.tag == TAG_STR {
                params.append(f"{p.name}: str");
                params.append(f"{p.name}_len: int");
            } elif p.tag == TAG_BOOL or _is_ref(p.tag) or p.tag == TAG_FN {
                params.append(f"{p.name}: int");
            } else {
                return None;
            }
        }
        ret = _base(fd.ret);
        if ret == TAG_VOID {
            pass;
        } elif ret == TAG_BOOL {
            params.append("out_bool: bytes");
        } elif _is_ref(fd.ret) {
            params.append("out_handle: bytes");
        } elif ret == TAG_STR {
            params.append("out_buf: bytes");
        } else {
            return None;
        }
        params.append("out_err: bytes");
        args = ",\n        ".join(params);
        return f"    def {fd.sym}(\n        {args}\n    ) -> i32;";
    }

    def _drain_and_raise(self: _Synth, fname: str) -> list {
        lines = [];
        if self.error_msg_sym {
            lines.append(
                f'            emsg = "{fname} failed with status " + str(st);'
            );
            lines.append('            mbuf = struct.pack("<QII", 0, 0, 0);');
            lines.append('            mben = struct.pack("<Q", 0);');
            lines.append(f"            mst = {self.error_msg_sym}(err_h, mbuf, mben);");
            lines.append("            if mst == 0 {");
            lines.append('                mb = struct.unpack("<QII", mbuf);');
            lines.append("                if mb[0] != 0 {");
            lines.append(
                "                    emsg = __jac_str_from_raw(mb[0], mb[1]);"
            );
            lines.append(
                f"                    {self.free_buf}(mb[0], mb[1] | (mb[2] << 32));"
            );
            lines.append("                }");
            lines.append("            }");
            if self.error_drop {
                lines.append(f"            {self.error_drop}(err_h);");
            }
            lines.append("            raise ValueError(emsg);");
        } else {
            if self.error_drop {
                lines.append(f"            {self.error_drop}(err_h);");
            }
            lines.append(
                f'            raise ValueError("{fname} failed with status " + str(st));'
            );
        }
        return lines;
    }

    def _method_body(self: _Synth, fd: object) -> object {
        body_lines = [];
        call = ["self.__handle"];
        for p in fd.params {
            if p.tag == TAG_STR {
                call.append(p.name);
                call.append(f"strlen({p.name})");
            } elif p.tag == TAG_BOOL {
                call.append(f"({p.name} and 1 or 0)");
            } elif _is_ref(p.tag) {
                call.append(f"{p.name}.__handle");
            } elif p.tag == TAG_FN {
                call.append(p.name);
                self._bridged_callback = True;
            } else {
                return None;
            }
        }
        body_lines.append("        if self.__closed {");
        body_lines.append(
            f'            raise RuntimeError("{fd.name} called after close()");'
        );
        body_lines.append("        }");
        if _is_ref(fd.ret) {
            if _ref_index(fd.ret) not in self.adoptable {
                return None;
            }
            body_lines.append('        out_h = struct.pack("<Q", 0);');
            call.append("out_h");
        } elif fd.ret == TAG_BOOL {
            body_lines.append('        out_b = struct.pack("<B", 0);');
            call.append("out_b");
        } elif _base(fd.ret) == TAG_STR {
            body_lines.append('        out_buf = struct.pack("<QII", 0, 0, 0);');
            call.append("out_buf");
            self._bridged_str_method = True;
        } elif _is_opt(fd.ret) {
            return None;
        } elif fd.ret != TAG_VOID {
            return None;
        }
        body_lines.append('        out_e = struct.pack("<Q", 0);');
        call.append("out_e");
        args = ", ".join(call);
        body_lines.append(f"        st = {fd.sym}({args});");
        body_lines.append("        if st != 0 {");
        body_lines.append('            err_h = struct.unpack("<Q", out_e)[0];');
        body_lines.extend(self._drain_and_raise(fd.name));
        body_lines.append("        }");
        if _is_ref(fd.ret) {
            target = self.opaque[_ref_index(fd.ret)];
            body_lines.append('        rh = struct.unpack("<Q", out_h)[0];');
            if _is_opt(fd.ret) {
                body_lines.append("        if rh == 0 {");
                body_lines.append("            return None;");
                body_lines.append("        }");
            }
            body_lines.append(f"        return {target}(rh);");
        } elif fd.ret == TAG_BOOL {
            body_lines.append('        return struct.unpack("<B", out_b)[0] != 0;');
        } elif _base(fd.ret) == TAG_STR {
            body_lines.append('        rb = struct.unpack("<QII", out_buf);');
            body_lines.append("        if rb[0] == 0 {");
            if _is_opt(fd.ret) {
                body_lines.append("            return None;");
            } else {
                body_lines.append('            return "";');
            }
            body_lines.append("        }");
            body_lines.append("        rs = __jac_str_from_raw(rb[0], rb[1]);");
            body_lines.append(
                f"        {self.free_buf}(rb[0], rb[1] | (rb[2] << 32));"
            );
            body_lines.append("        return rs;");
        }
        return body_lines;
    }

    def _ctor_body(self: _Synth, fd: object) -> object {
        body_lines = [];
        call = [];
        for p in fd.params {
            if p.tag == TAG_STR {
                call.append(p.name);
                call.append(f"strlen({p.name})");
            } elif p.tag == TAG_BOOL {
                call.append(f"({p.name} and 1 or 0)");
            } elif _is_ref(p.tag) {
                call.append(f"{p.name}.__handle");
            } elif p.tag == TAG_FN {
                call.append(p.name);
                self._bridged_callback = True;
            } else {
                return None;
            }
        }
        body_lines.append('        out_h = struct.pack("<Q", 0);');
        body_lines.append('        out_e = struct.pack("<Q", 0);');
        call.append("out_h");
        call.append("out_e");
        args = ", ".join(call);
        body_lines.append(f"        st = {fd.sym}({args});");
        body_lines.append("        if st == 0 {");
        body_lines.append('            self.__handle = struct.unpack("<Q", out_h)[0];');
        body_lines.append("            self.__closed = False;");
        body_lines.append("        } else {");
        body_lines.append('            err_h = struct.unpack("<Q", out_e)[0];');
        body_lines.extend(self._drain_and_raise(fd.name));
        body_lines.append("        }");
        return body_lines;
    }

    def _visit(self: _Synth, ti: int, produces: dict, visited: set, emit_order: list) {
        if ti in visited {
            return;
        }
        visited.add(ti);
        for p in sorted(produces[ti]) {
            self._visit(p, produces, visited, emit_order);
        }
        emit_order.append(ti);
    }

    def render(self: _Synth) -> NaModule {
        m = self.meta;
        ctor_of = {};
        methods_of = {ti: [] for ti in self.opaque};
        shim_fds = [];

        for fd in m.fns {
            if fd.kind == FN_CTOR
            and _is_ref(fd.ret)
            and _ref_index(fd.ret) in self.opaque {
                ti = _ref_index(fd.ret);
                if self._shim_decl(fd) is None or self._ctor_body(fd) is None {
                    self.skips.append(
                        Skip(
                            item=fd.name,
                            reason="constructor has unbridgeable param/return"
                        )
                    );
                    continue;
                }
                ctor_of[ti] = fd;
                shim_fds.append(fd);
            } elif fd.kind == FN_METHOD and fd.self_type in self.opaque {
                if self._shim_decl(fd) is None or self._method_body(fd) is None {
                    if _is_ref(fd.ret) and _ref_index(fd.ret) not in self.adoptable {
                        reason = "returns an opaque handle whose type has its own constructor (na adopt-ctor signature clash)";
                    } else {
                        reason = "unbridgeable param/return";
                    }
                    self.skips.append(
                        Skip(
                            item=f"{self.opaque[fd.self_type]}.{fd.name}", reason=reason
                        )
                    );
                    continue;
                }
                methods_of[fd.self_type].append(fd);
                shim_fds.append(fd);
            } elif fd.self_type != TAG_VOID
            and fd.self_type < len(m.types)
            and m.types[fd.self_type].kind == KIND_ERROR {
                if fd.sym != self.error_msg_sym {
                    self.skips.append(
                        Skip(
                            item=f"{m.types[fd.self_type].name}.{fd.name}",
                            reason="error-type method not bridged on na"
                        )
                    );
                }
            }
        }

        out = [];
        out.append(
            f"# AUTO-SYNTHESIZED from {self.so} (.jac_bridge metadata). Do not edit."
        );
        out.append(f"# module: {m.module_name}   abi: {m.abi_version}");
        out.append("import struct;");
        out.append('import from "libc.so.6" {');
        out.append("    def strlen(s: str) -> int;");
        out.append("}");
        out.append("");
        out.append(f'import from "{self.so}" {{');
        for fd in shim_fds {
            out.append(self._shim_decl(fd));
        }
        for ti in self.opaque {
            td = m.types[ti];
            if td.drop_sym {
                out.append(f"    def {td.drop_sym}(handle: int) -> None;");
            }
        }
        if self.error_drop {
            out.append(f"    def {self.error_drop}(err_handle: int) -> None;");
        }
        if self.error_msg_sym {
            out.append(
                f"    def {self.error_msg_sym}" + "(err_handle: int, out_buf: bytes, out_err: bytes) -> i32;"
            );
        }
        if self.error_msg_sym or self._bridged_str_method {
            out.append(
                f"    def {self.free_buf}(buf_ptr: int, buf_lencap: int) -> None;"
            );
        }
        if self._bridged_callback {
            out.append(
                f"    def {self.make_buf_sym}(s: str, s_len: int, out_buf: int) -> None;"
            );
        }
        out.append("}");
        out.append("");

        produces = {ti: set() for ti in self.opaque};
        for ti in self.opaque {
            for fd in methods_of.get(ti, []) {
                if _is_ref(fd.ret) {
                    p = _ref_index(fd.ret);
                    if p in self.opaque and p != ti {
                        produces[ti].add(p);
                    }
                }
            }
        }
        emit_order = [];
        visited = set();
        seed = sorted(
            [
                t
                for t in self.opaque
                if t in self.adoptable
            ]
        ) + sorted(
            [
                t
                for t in self.opaque
                if t not in self.adoptable
            ]
        );
        for ti in seed {
            self._visit(ti, produces, visited, emit_order);
        }

        for ti in emit_order {
            name = self.opaque[ti];
            drop_sym = m.types[ti].drop_sym;
            out.append(f"obj {name} {{");
            out.append("    has __handle: int = 0;");
            out.append("    has __closed: bool = True;");
            out.append("");
            ctor = ctor_of.get(ti);
            if ctor is not None {
                sig = self._ctor_params(ctor);
                out.append(f"    def init({sig}) {{");
                out.extend(self._ctor_body(ctor));
                out.append("    }");
                out.append("");
            } elif ti in self.adoptable {
                out.append("    def init(raw: int) {");
                out.append("        self.__handle = raw;");
                out.append("        self.__closed = False;");
                out.append("    }");
                out.append("");
            }
            for fd in methods_of.get(ti, []) {
                sig = self._method_params(fd);
                ret = self._ret_ann(fd);
                out.append(f"    def {fd.name}({sig}){ret} {{");
                out.extend(self._method_body(fd));
                out.append("    }");
                out.append("");
            }
            out.append("    def close() {");
            out.append("        if not self.__closed {");
            if drop_sym {
                out.append(f"            {drop_sym}(self.__handle);");
            }
            out.append("            self.__handle = 0;");
            out.append("            self.__closed = True;");
            out.append("        }");
            out.append("    }");
            out.append("");
            out.append("    def __del__() {");
            out.append("        self.close();");
            out.append("    }");
            out.append("}");
            out.append("");
        }

        bridged = len(ctor_of) + sum([len(v) for v in methods_of.values()]);
        return NaModule(source="\n".join(out), skips=self.skips, bridged=bridged);
    }

    def _jac_param(self: _Synth, p: object) -> str {
        if p.tag == TAG_STR {
            return f"{p.name}: str";
        }
        if p.tag == TAG_BOOL {
            return f"{p.name}: bool";
        }
        if _is_ref(p.tag) {
            return f"{p.name}: {self.opaque.get(_ref_index(p.tag), 'object')}";
        }
        return f"{p.name}: int";
    }

    def _ctor_params(self: _Synth, fd: object) -> str {
        return ", ".join([self._jac_param(p) for p in fd.params]);
    }

    def _method_params(self: _Synth, fd: object) -> str {
        return ", ".join([self._jac_param(p) for p in fd.params]);
    }

    def _ret_ann(self: _Synth, fd: object) -> str {
        if _base(fd.ret) == TAG_BOOL {
            return " -> bool";
        }
        if _base(fd.ret) == TAG_STR {
            return " -> str | None" if _is_opt(fd.ret) else " -> str";
        }
        if _is_ref(fd.ret) {
            t = self.opaque.get(_ref_index(fd.ret), "object");
            return f" -> {t} | None" if _is_opt(fd.ret) else f" -> {t}";
        }
        return "";
    }
}


def render_na_source(meta: object, so_basename: str) -> NaModule {
    return _Synth(meta, so_basename).render();
}

"""Synthesize Jac SOURCE for a bridge module from parsed D2 metadata.

This is the na (native/AOT) analog of ``_codegen.build_module`` (which builds a
live Python module via ctypes).  Here we emit Jac *source text* shaped exactly
like the hand-written golden spike
(``bridges/jac-bridge-regex/jac/regex_native.jac``).  The M3 na loader parses the
``.jac_bridge`` section, calls this to get source, and feeds it through the normal
Jac parse→typecheck→native-codegen pipeline — so all the marshaling rides on the
existing foreign-FFI + obj + RC-dtor machinery.  No IR is emitted here.

Marshaling recipe (proven natively — see the golden spike):
  * string IN  -> foreign param ``str`` (na passes the char* data ptr) plus an
    explicit ``int`` byte length obtained from libc ``strlen`` (na ``len()`` on a
    str parameter is not implemented in the native backend).
  * out-params -> foreign param ``bytes``; na lowers a bytes arg to an i8* param
    as its data pointer, so the shim writes into a pre-sized ``struct.pack``
    buffer that we then ``struct.unpack``.
  * ``i32`` status: 0 ok / 1 err / 2 panic -> raise on non-zero.
  * opaque handle stored in ``has __handle: int``; ``def __del__`` is the RC dtor.

Scope: opaque types, constructors, and methods whose params are scalar/str and
whose return is void / bool / opaque-handle / **str**.  A JacBuf string return is
read into an owned Jac str via the ``__jac_str_from_raw`` na intrinsic and the
bridge buffer freed via ``jac_<module>_free_buf`` (passed as two ints — the
by-value ABI of a ``{ptr,len,cap}`` struct).  The error type's ``message()`` is
consumed the same way: its text is decoded and raised on the exception, so na
error messages match the CPython loader instead of a synthetic status string.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from ._blob import (
    FN_CTOR,
    FN_METHOD,
    KIND_ERROR,
    KIND_OPAQUE,
    TAG_BOOL,
    TAG_OPT_BIT,
    TAG_REF_BIT,
    TAG_STR,
    TAG_VOID,
    BridgeMeta,
    FnDesc,
    ParamDesc,
)


@dataclass
class Skip:
    """A public item the synthesizer could not bridge, with a reason (D6)."""

    item: str
    reason: str


@dataclass
class NaModule:
    source: str
    skips: list[Skip] = field(default_factory=list)


def _base(tag: int) -> int:
    """Strip the nullable Option<T> marker; the inner tag rides the same slot."""
    return tag & ~TAG_OPT_BIT


def _is_opt(tag: int) -> bool:
    return bool(tag & TAG_OPT_BIT)


def _is_ref(tag: int) -> bool:
    base = _base(tag)
    return bool(base & TAG_REF_BIT) and base != TAG_VOID


def _ref_index(tag: int) -> int:
    return _base(tag) & ~TAG_REF_BIT


def _drop_sym_for(meta: BridgeMeta, kind: int) -> str | None:
    for td in meta.types:
        if td.kind == kind and td.drop_sym:
            return td.drop_sym
    return None


class _Synth:
    def __init__(self, meta: BridgeMeta, so_basename: str) -> None:
        self.meta = meta
        self.so = so_basename
        self.skips: list[Skip] = []
        # opaque type index -> Jac type name
        self.opaque = {td.index: td.name for td in meta.types if td.kind == KIND_OPAQUE}
        self.error_drop = _drop_sym_for(meta, KIND_ERROR)
        # An error handle (user error OR panic) is a Box<String>; its message()
        # fn decodes it into a JacBuf.  We read that text natively (via the
        # __jac_str_from_raw intrinsic) and put it on the raised exception, so na
        # error text matches the CPython loader instead of a synthetic status.
        self.error_msg_sym: str | None = None
        for fd in meta.fns:
            if (
                fd.name == "message"
                and fd.ret == TAG_STR
                and fd.self_type != TAG_VOID
                and fd.self_type < len(meta.types)
                and meta.types[fd.self_type].kind == KIND_ERROR
            ):
                self.error_msg_sym = fd.sym
                break
        # By convention every jac-bridge crate exports jac_<module>_free_buf,
        # which frees a JacBuf BY VALUE.  A #[repr(C)] {ptr:u64, len:u32, cap:u32}
        # is two SysV eightbytes (both INTEGER), so we call it as two ints:
        # (ptr, len | cap<<32) — matching what the by-value ABI puts in rdi/rsi.
        self.free_buf = f"jac_{meta.module_name}_free_buf"
        self._bridged_str_method = False

    # -- foreign shim declaration for one fn --------------------------------

    def _shim_decl(self, fd: FnDesc) -> str | None:
        params: list[str] = []
        if fd.kind == FN_METHOD and fd.self_type != TAG_VOID:
            params.append("handle: int")
        for p in fd.params:
            if p.tag == TAG_STR:
                params.append(f"{p.name}: str")
                params.append(f"{p.name}_len: int")
            elif p.tag == TAG_BOOL or _is_ref(p.tag):
                params.append(f"{p.name}: int")
            else:
                # unsupported param type -> caller skips the whole fn
                return None
        # return out-slot(s) — a nullable Option<T> shares its inner tag's slot.
        ret = _base(fd.ret)
        if ret == TAG_VOID:
            pass
        elif ret == TAG_BOOL:
            params.append("out_bool: bytes")
        elif _is_ref(fd.ret):
            params.append("out_handle: bytes")
        elif ret == TAG_STR:
            params.append("out_buf: bytes")  # 16-byte JacBuf out-slot
        else:
            # other return -> not supported in v1
            return None
        params.append("out_err: bytes")
        args = ",\n        ".join(params)
        return f"    def {fd.sym}(\n        {args}\n    ) -> i32;"

    # -- error drain --------------------------------------------------------

    def _drain_and_raise(self, fname: str) -> list[str]:
        """Lines (12-space indent) that turn a live `err_h` + `st` into a raise.

        With a message fn we read the real Rust error text via the JacBuf helper
        and raise that (matching the CPython loader); otherwise we fall back to a
        synthetic status message.  Either way the error handle is dropped.
        """
        lines: list[str] = []
        if self.error_msg_sym:
            lines.append(f'            emsg = "{fname} failed with status " + str(st);')
            lines.append('            mbuf = struct.pack("<QII", 0, 0, 0);')
            lines.append('            mben = struct.pack("<Q", 0);')
            lines.append(f"            mst = {self.error_msg_sym}(err_h, mbuf, mben);")
            lines.append("            if mst == 0 {")
            lines.append('                mb = struct.unpack("<QII", mbuf);')
            lines.append("                if mb[0] != 0 {")
            lines.append("                    emsg = __jac_str_from_raw(mb[0], mb[1]);")
            lines.append(
                f"                    {self.free_buf}(mb[0], mb[1] | (mb[2] << 32));"
            )
            lines.append("                }")
            lines.append("            }")
            if self.error_drop:
                lines.append(f"            {self.error_drop}(err_h);")
            lines.append("            raise ValueError(emsg);")
        else:
            if self.error_drop:
                lines.append(f"            {self.error_drop}(err_h);")
            lines.append(
                f'            raise ValueError("{fname} failed with status " + str(st));'
            )
        return lines

    # -- method / ctor body -------------------------------------------------

    def _method_body(self, fd: FnDesc) -> list[str] | None:
        """Body lines for a non-ctor instance method.  None if unbridgeable."""
        lines: list[str] = []
        # marshal args
        call = ["self.__handle"]
        for p in fd.params:
            if p.tag == TAG_STR:
                call.append(p.name)
                call.append(f"strlen({p.name})")
            elif p.tag == TAG_BOOL:
                call.append(f"({p.name} and 1 or 0)")
            elif _is_ref(p.tag):
                call.append(f"{p.name}.__handle")
            else:
                return None
        lines.append("        if self.__closed {")
        lines.append(
            f'            raise RuntimeError("{fd.name} called after close()");'
        )
        lines.append("        }")
        # out slots. A nullable Option<T> return is deferred on na: Option<Ref>
        # needs the (missing) bare-construct path, and Option<Str> would need Jac
        # optional typing to distinguish None from "" — mapping null->"" would
        # silently conflate the two. Both stay honest skips until na verification.
        if _is_opt(fd.ret):
            return None
        if fd.ret == TAG_BOOL:
            lines.append('        out_b = struct.pack("<B", 0);')
            call.append("out_b")
        elif fd.ret == TAG_STR:
            lines.append('        out_buf = struct.pack("<QII", 0, 0, 0);')
            call.append("out_buf")
            self._bridged_str_method = True
        elif fd.ret != TAG_VOID:
            # opaque-handle return: needs constructing an obj around a raw handle
            # WITHOUT re-running its ctor (no na "bare construct" path yet).
            # Deferred in v1.
            return None
        lines.append('        out_e = struct.pack("<Q", 0);')
        call.append("out_e")
        args = ", ".join(call)
        lines.append(f"        st = {fd.sym}({args});")
        lines.append("        if st != 0 {")
        lines.append('            err_h = struct.unpack("<Q", out_e)[0];')
        lines.extend(self._drain_and_raise(fd.name))
        lines.append("        }")
        if fd.ret == TAG_BOOL:
            lines.append('        return struct.unpack("<B", out_b)[0] != 0;')
        elif fd.ret == TAG_STR:
            # JacBuf out-slot -> owned Jac str; free the bridge buffer after copy.
            lines.append('        rb = struct.unpack("<QII", out_buf);')
            lines.append("        if rb[0] == 0 {")
            lines.append('            return "";')
            lines.append("        }")
            lines.append("        rs = __jac_str_from_raw(rb[0], rb[1]);")
            lines.append(f"        {self.free_buf}(rb[0], rb[1] | (rb[2] << 32));")
            lines.append("        return rs;")
        # void: no return
        return lines

    def _ctor_body(self, fd: FnDesc) -> list[str] | None:
        lines: list[str] = []
        call = []
        for p in fd.params:
            if p.tag == TAG_STR:
                call.append(p.name)
                call.append(f"strlen({p.name})")
            elif p.tag == TAG_BOOL:
                call.append(f"({p.name} and 1 or 0)")
            elif _is_ref(p.tag):
                call.append(f"{p.name}.__handle")
            else:
                return None
        lines.append('        out_h = struct.pack("<Q", 0);')
        lines.append('        out_e = struct.pack("<Q", 0);')
        call.append("out_h")
        call.append("out_e")
        args = ", ".join(call)
        lines.append(f"        st = {fd.sym}({args});")
        lines.append("        if st == 0 {")
        lines.append('            self.__handle = struct.unpack("<Q", out_h)[0];')
        lines.append("            self.__closed = False;")
        lines.append("        } else {")
        lines.append('            err_h = struct.unpack("<Q", out_e)[0];')
        lines.extend(self._drain_and_raise(fd.name))
        lines.append("        }")
        return lines

    # -- assemble -----------------------------------------------------------

    def render(self) -> NaModule:
        m = self.meta
        # group fns
        ctor_of: dict[int, FnDesc] = {}
        methods_of: dict[int, list[FnDesc]] = {ti: [] for ti in self.opaque}
        shim_fds: list[FnDesc] = []

        for fd in m.fns:
            if (
                fd.kind == FN_CTOR
                and _is_ref(fd.ret)
                and _ref_index(fd.ret) in self.opaque
            ):
                ti = _ref_index(fd.ret)
                if self._shim_decl(fd) is None or self._ctor_body(fd) is None:
                    self.skips.append(
                        Skip(fd.name, "constructor has unbridgeable param/return")
                    )
                    continue
                ctor_of[ti] = fd
                shim_fds.append(fd)
            elif fd.kind == FN_METHOD and fd.self_type in self.opaque:
                if self._shim_decl(fd) is None or self._method_body(fd) is None:
                    if _is_opt(fd.ret) and _is_ref(fd.ret):
                        reason = "returns Option<opaque handle> (no na bare-construct path yet)"
                    elif _is_opt(fd.ret) and _base(fd.ret) == TAG_STR:
                        reason = "returns Option<str> (nullable->None mapping deferred on na)"
                    elif fd.ret == TAG_STR:
                        reason = "returns a string (JacBuf->str read not yet supported on na)"
                    elif _is_ref(fd.ret):
                        reason = (
                            "returns an opaque handle (no na bare-construct path yet)"
                        )
                    else:
                        reason = "unbridgeable param/return"
                    self.skips.append(
                        Skip(f"{self.opaque[fd.self_type]}.{fd.name}", reason)
                    )
                    continue
                methods_of[fd.self_type].append(fd)
                shim_fds.append(fd)
            elif (
                fd.self_type != TAG_VOID
                and fd.self_type < len(m.types)
                and m.types[fd.self_type].kind == KIND_ERROR
            ):
                # message() is consumed into raised-exception text (see
                # _drain_and_raise), not exposed as a standalone method; any other
                # error-type method is still out of scope.
                if fd.sym != self.error_msg_sym:
                    self.skips.append(
                        Skip(
                            f"{m.types[fd.self_type].name}.{fd.name}",
                            "error-type method not bridged on na",
                        )
                    )
            # else: free functions — none in the regex bridge

        out: list[str] = []
        out.append(
            f"# AUTO-SYNTHESIZED from {self.so} (.jac_bridge metadata). Do not edit."
        )
        out.append(f"# module: {m.module_name}   abi: {m.abi_version}")
        out.append("import struct;")
        out.append('import from "libc.so.6" {')
        out.append("    def strlen(s: str) -> int;")
        out.append("}")
        out.append("")
        out.append(f'import from "{self.so}" {{')
        for fd in shim_fds:
            out.append(self._shim_decl(fd))
        # drop shims for opaque types
        for ti, _name in self.opaque.items():
            td = m.types[ti]
            if td.drop_sym:
                out.append(f"    def {td.drop_sym}(handle: int) -> None;")
        if self.error_drop:
            out.append(f"    def {self.error_drop}(err_handle: int) -> None;")
        if self.error_msg_sym:
            out.append(
                f"    def {self.error_msg_sym}"
                "(err_handle: int, out_buf: bytes, out_err: bytes) -> i32;"
            )
        if self.error_msg_sym or self._bridged_str_method:
            # frees a JacBuf by value; see __init__ for the two-int ABI note.
            out.append(
                f"    def {self.free_buf}(buf_ptr: int, buf_lencap: int) -> None;"
            )
        out.append("}")
        out.append("")

        for ti, name in self.opaque.items():
            drop_sym = m.types[ti].drop_sym
            out.append(f"obj {name} {{")
            out.append("    has __handle: int = 0;")
            out.append("    has __closed: bool = True;")
            out.append("")
            ctor = ctor_of.get(ti)
            if ctor is not None:
                sig = self._ctor_params(ctor)
                out.append(f"    def init({sig}) {{")
                out.extend(self._ctor_body(ctor))
                out.append("    }")
                out.append("")
            for fd in methods_of.get(ti, []):
                sig = self._method_params(fd)
                ret = self._ret_ann(fd)
                out.append(f"    def {fd.name}({sig}){ret} {{")
                out.extend(self._method_body(fd))
                out.append("    }")
                out.append("")
            out.append("    def close() {")
            out.append("        if not self.__closed {")
            if drop_sym:
                out.append(f"            {drop_sym}(self.__handle);")
            out.append("            self.__handle = 0;")
            out.append("            self.__closed = True;")
            out.append("        }")
            out.append("    }")
            out.append("")
            out.append("    def __del__() {")
            out.append("        self.close();")
            out.append("    }")
            out.append("}")
            out.append("")

        return NaModule("\n".join(out), self.skips)

    # -- Jac-visible signatures --------------------------------------------

    def _jac_param(self, p: ParamDesc) -> str:
        if p.tag == TAG_STR:
            return f"{p.name}: str"
        if p.tag == TAG_BOOL:
            return f"{p.name}: bool"
        if _is_ref(p.tag):
            return f"{p.name}: {self.opaque.get(_ref_index(p.tag), 'object')}"
        return f"{p.name}: int"

    def _ctor_params(self, fd: FnDesc) -> str:
        return ", ".join(self._jac_param(p) for p in fd.params)

    def _method_params(self, fd: FnDesc) -> str:
        return ", ".join(self._jac_param(p) for p in fd.params)

    def _ret_ann(self, fd: FnDesc) -> str:
        if fd.ret == TAG_BOOL:
            return " -> bool"
        if _is_ref(fd.ret):
            return " -> " + self.opaque.get(_ref_index(fd.ret), "object")
        return ""


def render_na_source(meta: BridgeMeta, so_basename: str) -> NaModule:
    """Public entry point: parsed metadata + the library basename to NEED-link."""
    return _Synth(meta, so_basename).render()

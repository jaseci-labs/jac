impl NaIRGenPass._get_file_struct_type -> ir.Type {
    if self._file_struct_type is not None {
        return self._file_struct_type;
    }
    self._file_struct_type = self._register_file_like_struct("File");
    return self._file_struct_type;
}

impl NaIRGenPass._get_binary_file_struct_type -> ir.Type {
    if self._binary_file_struct_type is not None {
        return self._binary_file_struct_type;
    }
    self._binary_file_struct_type = self._register_file_like_struct("BinaryFile");
    return self._binary_file_struct_type;
}

impl NaIRGenPass._register_file_like_struct(name: str) -> ir.Type {
    i8p = ir.IntType(8).as_pointer();
    i1 = ir.IntType(1);
    st = self.llvm_module.context.get_identified_type(name);
    st.set_body(i8p, i8p, i8p, i1);
    self.struct_types[name] = st;
    self.struct_field_indices[name] = {"handle": 0, "path": 1, "mode": 2, "closed": 3};
    self.struct_field_types[name] = {
        "handle": i8p,
        "path": i8p,
        "mode": i8p,
        "closed": i1
    };
    self.struct_field_defaults[name] = {};
    return st;
}

impl NaIRGenPass._emit_file_helpers -> None {
    if self._file_helpers_emitted {
        return;
    }
    self._file_helpers_emitted = True;
    self._emit_file_like_helpers("File", self._get_file_struct_type(), binary=False);
}

impl NaIRGenPass._emit_binary_file_helpers -> None {
    if self._binary_file_helpers_emitted {
        return;
    }
    self._binary_file_helpers_emitted = True;
    self._emit_file_like_helpers(
        "BinaryFile", self._get_binary_file_struct_type(), binary=True
    );
}

impl NaIRGenPass._emit_file_like_helpers(
    struct_name: str, struct_type: ir.Type, binary: bool
) -> None {
    file_ptr_type = struct_type.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    z32 = ir.Constant(i32, 0);
    one32 = ir.Constant(i32, 1);
    fclose_fn = self._get_or_declare_extern("fclose", i32, [i8p]);
    fread_fn = self._get_or_declare_extern("fread", i64, [i8p, i64, i64, i8p]);
    fwrite_fn = self._get_or_declare_extern("fwrite", i64, [i8p, i64, i64, i8p]);
    fgets_fn = self._get_or_declare_extern("fgets", i8p, [i8p, i32, i8p]);
    fflush_fn = self._get_or_declare_extern("fflush", i32, [i8p]);
    ftell_fn = self._get_or_declare_extern("ftell", i64, [i8p]);
    fseek_fn = self._get_or_declare_extern("fseek", i32, [i8p, i64, i32]);
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    rc_alloc_fn = self.rc_alloc_fn;
    bt = self._get_bytes_struct_type();
    bytes_ptr_type = bt.as_pointer();

    read_ret = bytes_ptr_type if binary else i8p;

    read_fnty = ir.FunctionType(read_ret, [file_ptr_type]);
    read_fn = ir.Function(self.llvm_module, read_fnty, name=f"{struct_name}.read");
    read_fn.linkage = "private";
    read_fn.args[0].name = "self";
    bb = read_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    self_arg = read_fn.args[0];
    handle_ptr = b.gep(self_arg, [z32, z32], name="handle.ptr");
    handle = b.load(handle_ptr, name="handle");
    b.call(fseek_fn, [handle, ir.Constant(i64, 0), ir.Constant(i32, 2)]);
    file_size = b.call(ftell_fn, [handle], name="file.size");
    b.call(fseek_fn, [handle, ir.Constant(i64, 0), ir.Constant(i32, 0)]);
    if binary {
        total = b.add(file_size, ir.Constant(i64, 8), name="rd.total");
        raw = b.call(rc_alloc_fn, [total], name="rd.raw");
        self._emit_set_type_tag(b, raw, "bytes");
        bv = b.bitcast(raw, bytes_ptr_type, name="rd.bytes");
        len_ptr = b.gep(bv, [z32, z32], name="rd.len.ptr");
        b.store(file_size, len_ptr);
        arr_ptr = b.gep(bv, [z32, one32], name="rd.data.arr");
        data_ptr = b.bitcast(arr_ptr, i8p, name="rd.data");
        b.call(fread_fn, [data_ptr, ir.Constant(i64, 1), file_size, handle]);
        b.ret(bv);
    } else {
        buf_size = b.add(file_size, ir.Constant(i64, 1), name="buf.size");
        buffer = b.call(rc_alloc_fn, [buf_size], name="read.buf");
        self._emit_set_type_tag(b, buffer, "str");
        bytes_read = b.call(
            fread_fn,
            [buffer, ir.Constant(i64, 1), file_size, handle],
            name="bytes.read"
        );
        null_pos = b.gep(buffer, [bytes_read], name="null.pos");
        b.store(ir.Constant(i8, 0), null_pos);
        b.ret(buffer);
    }

    write_arg = bytes_ptr_type if binary else i8p;
    write_fnty = ir.FunctionType(i64, [file_ptr_type, write_arg]);
    write_fn = ir.Function(self.llvm_module, write_fnty, name=f"{struct_name}.write");
    write_fn.linkage = "private";
    write_fn.args[0].name = "self";
    write_fn.args[1].name = "data";
    bb = write_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    self_arg = write_fn.args[0];
    data_arg = write_fn.args[1];
    handle_ptr = b.gep(self_arg, [z32, z32], name="handle.ptr");
    handle = b.load(handle_ptr, name="handle");
    if binary {
        len_ptr = b.gep(data_arg, [z32, z32], name="wr.len.ptr");
        data_len = b.load(len_ptr, name="wr.len");
        arr_ptr = b.gep(data_arg, [z32, one32], name="wr.data.arr");
        src_ptr = b.bitcast(arr_ptr, i8p, name="wr.data");
    } else {
        data_len = b.call(strlen_fn, [data_arg], name="data.len");
        src_ptr = data_arg;
    }
    written = b.call(
        fwrite_fn, [src_ptr, ir.Constant(i64, 1), data_len, handle], name="written"
    );
    b.ret(written);

    readline_fnty = ir.FunctionType(read_ret, [file_ptr_type]);
    readline_fn = ir.Function(
        self.llvm_module, readline_fnty, name=f"{struct_name}.readline"
    );
    readline_fn.linkage = "private";
    readline_fn.args[0].name = "self";
    bb = readline_fn.append_basic_block("entry");
    eof_bb = readline_fn.append_basic_block("eof");
    ok_bb = readline_fn.append_basic_block("ok");
    b = ir.IRBuilder(bb);
    self_arg = readline_fn.args[0];
    handle_ptr = b.gep(self_arg, [z32, z32], name="handle.ptr");
    handle = b.load(handle_ptr, name="handle");
    if binary {
        null_i8p = ir.Constant(i8p, None);
        n_slot = b.alloca(i64, name="rl.n");
        b.store(ir.Constant(i64, 0), n_slot);
        lp_slot = b.alloca(i8p, name="rl.lp");
        b.store(null_i8p, lp_slot);
        getdelim_fn = self._get_or_declare_extern(
            "getdelim", i64, [i8p.as_pointer(), i64.as_pointer(), i32, i8p]
        );
        free_fn2 = self._get_or_declare_extern("free", ir.VoidType(), [i8p]);
        count = b.call(
            getdelim_fn,
            [lp_slot, n_slot, ir.Constant(i32, 10), handle],
            name="rl.count"
        );
        is_eof = b.icmp_signed("<", count, ir.Constant(i64, 0), name="rl.eof");
        b.cbranch(is_eof, eof_bb, ok_bb);

        b.position_at_end(eof_bb);
        b.call(free_fn2, [b.load(lp_slot, name="rl.lp.eof")]);
        e_raw = b.call(rc_alloc_fn, [ir.Constant(i64, 8)], name="rl.eof.raw");
        self._emit_set_type_tag(b, e_raw, "bytes");
        e_bv = b.bitcast(e_raw, bytes_ptr_type, name="rl.eof.bytes");
        b.store(ir.Constant(i64, 0), b.gep(e_bv, [z32, z32], name="rl.eof.len"));
        b.ret(e_bv);

        b.position_at_end(ok_bb);
        lp = b.load(lp_slot, name="rl.lp.ok");
        rl_total = b.add(count, ir.Constant(i64, 8), name="rl.total");
        rl_raw = b.call(rc_alloc_fn, [rl_total], name="rl.raw");
        self._emit_set_type_tag(b, rl_raw, "bytes");
        rl_bv = b.bitcast(rl_raw, bytes_ptr_type, name="rl.bytes");
        b.store(count, b.gep(rl_bv, [z32, z32], name="rl.len.ptr"));
        rl_data = b.bitcast(
            b.gep(rl_bv, [z32, one32], name="rl.data.arr"), i8p, name="rl.data"
        );
        b.call(memcpy_fn, [rl_data, lp, count]);
        b.call(free_fn2, [lp]);
        b.ret(rl_bv);
    } else {
        buf_sz = 4096;
        buf = b.alloca(ir.ArrayType(i8, buf_sz), name="line.buf");
        buf_ptr = b.bitcast(buf, i8p, name="line.ptr");
        result = b.call(
            fgets_fn, [buf_ptr, ir.Constant(i32, buf_sz), handle], name="fgets.result"
        );
        is_eof = b.icmp_signed("==", result, ir.Constant(i8p, None), name="is.eof");
        b.cbranch(is_eof, eof_bb, ok_bb);
        b.position_at_end(eof_bb);
        empty = b.call(rc_alloc_fn, [ir.Constant(i64, 1)], name="empty.str");
        self._emit_set_type_tag(b, empty, "str");
        b.store(ir.Constant(i8, 0), empty);
        b.ret(empty);
        b.position_at_end(ok_bb);
        slen = b.call(strlen_fn, [buf_ptr], name="line.len");
        alloc_size = b.add(slen, ir.Constant(i64, 1), name="alloc.size");
        line_str = b.call(rc_alloc_fn, [alloc_size], name="line.str");
        self._emit_set_type_tag(b, line_str, "str");
        b.call(memcpy_fn, [line_str, buf_ptr, alloc_size]);
        b.ret(line_str);
    }

    close_fnty = ir.FunctionType(ir.VoidType(), [file_ptr_type]);
    close_fn = ir.Function(self.llvm_module, close_fnty, name=f"{struct_name}.close");
    close_fn.linkage = "private";
    close_fn.args[0].name = "self";
    bb = close_fn.append_basic_block("entry");
    already_closed_bb = close_fn.append_basic_block("already.closed");
    do_close_bb = close_fn.append_basic_block("do.close");
    b = ir.IRBuilder(bb);
    self_arg = close_fn.args[0];
    closed_ptr = b.gep(self_arg, [z32, ir.Constant(i32, 3)], name="closed.ptr");
    is_closed = b.load(closed_ptr, name="is.closed");
    b.cbranch(is_closed, already_closed_bb, do_close_bb);
    b.position_at_end(already_closed_bb);
    b.ret_void();
    b.position_at_end(do_close_bb);
    handle_ptr = b.gep(self_arg, [z32, z32], name="handle.ptr");
    handle = b.load(handle_ptr, name="handle");
    b.call(fclose_fn, [handle]);
    b.store(ir.Constant(i1, 1), closed_ptr);
    b.ret_void();

    flush_fnty = ir.FunctionType(ir.VoidType(), [file_ptr_type]);
    flush_fn = ir.Function(self.llvm_module, flush_fnty, name=f"{struct_name}.flush");
    flush_fn.linkage = "private";
    flush_fn.args[0].name = "self";
    bb = flush_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    self_arg = flush_fn.args[0];
    handle_ptr = b.gep(self_arg, [z32, z32], name="handle.ptr");
    handle = b.load(handle_ptr, name="handle");
    b.call(fflush_fn, [handle]);
    b.ret_void();

    enter_fnty = ir.FunctionType(file_ptr_type, [file_ptr_type]);
    enter_fn = ir.Function(
        self.llvm_module, enter_fnty, name=f"{struct_name}.__enter__"
    );
    enter_fn.linkage = "private";
    enter_fn.args[0].name = "self";
    bb = enter_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    b.ret(enter_fn.args[0]);

    exit_fnty = ir.FunctionType(i1, [file_ptr_type, i8p, i8p, i8p]);
    exit_fn = ir.Function(self.llvm_module, exit_fnty, name=f"{struct_name}.__exit__");
    exit_fn.linkage = "private";
    exit_fn.args[0].name = "self";
    exit_fn.args[1].name = "exc_type";
    exit_fn.args[2].name = "exc_val";
    exit_fn.args[3].name = "traceback";
    bb = exit_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    b.call(close_fn, [exit_fn.args[0]]);
    b.ret(ir.Constant(i1, 0));

    _methods = {
        f"{struct_name}.read": read_fn,
        f"{struct_name}.write": write_fn,
        f"{struct_name}.readline": readline_fn,
        f"{struct_name}.close": close_fn,
        f"{struct_name}.flush": flush_fn,
        f"{struct_name}.__enter__": enter_fn,
        f"{struct_name}.__exit__": exit_fn
    };
    for (_mname, _mfn) in _methods.items() {
        self.method_funcs[_mname] = _mfn;
        self.func_symtab[_mname] = _mfn;
    }
}

impl NaIRGenPass._emit_open(nd: uni.FuncCall) -> (ir.Value | None) {
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    params = nd.params or [];
    if not params {
        return None;
    }
    path_val = self._codegen_expr(params[0]);
    if path_val is None {
        return None;
    }

    mode_literal: (str | None) = None;
    if len(params) >= 2 {
        _mnode = params[1];
        if isinstance(_mnode, uni.MultiString) and len(_mnode.strings) == 1 {
            _mnode = _mnode.strings[0];
        }
        if isinstance(_mnode, uni.String) {
            _mlv = _mnode.lit_value;
            if isinstance(_mlv, str) {
                mode_literal = _mlv;
            }
        }
    }

    mode_val: (ir.Value | None) = None;
    if len(params) >= 2 {
        mode_val = self._codegen_expr(params[1]);
        if mode_val is not None and mode_val.type != i8p {
            return None;
        }
    }
    if mode_val is None {
        mode_val = self._make_global_string("r", name_prefix=".file.mode");
    }
    is_binary = mode_literal is not None and "b" in mode_literal;
    if is_binary {
        struct_type = self._get_binary_file_struct_type();
        self._emit_binary_file_helpers();
    } else {
        struct_type = self._get_file_struct_type();
        self._emit_file_helpers();
    }
    file_ptr_type = struct_type.as_pointer();
    fopen_fn = self._get_or_declare_extern("fopen", i8p, [i8p, i8p]);
    file_handle = self.builder.call(
        fopen_fn, [path_val, mode_val], name="fopen.result"
    );

    null_ptr = ir.Constant(i8p, None);
    is_null = self.builder.icmp_signed("==", file_handle, null_ptr, name="fopen.null");
    self._emit_runtime_raise(is_null, "FileNotFoundError", "No such file or directory");

    null_file_ptr = ir.Constant(file_ptr_type, None);
    size_gep = self.builder.gep(
        null_file_ptr, [ir.Constant(i32, 1)], name="file.sizeof"
    );
    file_size = self.builder.ptrtoint(size_gep, i64, name="file.size");
    self._set_rc_ctx("file_read", "");
    raw = self.builder.call(self.rc_alloc_fn, [file_size], name="file.raw");
    self._clear_rc_ctx();
    file_obj = self.builder.bitcast(raw, file_ptr_type, name="file.obj");
    handle_ptr = self.builder.gep(
        file_obj, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="file.handle.ptr"
    );
    self.builder.store(file_handle, handle_ptr);
    path_ptr = self.builder.gep(
        file_obj, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="file.path.ptr"
    );
    self.builder.store(path_val, path_ptr);
    mode_ptr = self.builder.gep(
        file_obj, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="file.mode.ptr"
    );
    self.builder.store(mode_val, mode_ptr);
    closed_ptr = self.builder.gep(
        file_obj, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="file.closed.ptr"
    );
    self.builder.store(ir.Constant(i1, 0), closed_ptr);
    return file_obj;
}

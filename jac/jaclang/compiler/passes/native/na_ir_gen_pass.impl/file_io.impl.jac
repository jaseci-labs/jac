"""File I/O codegen: File struct, open() builtin, and File methods.

The File type is a built-in archetype with:
  [0] i8*  handle   — FILE* from fopen
  [1] i8*  path     — file path string
  [2] i8*  mode     — mode string ("r", "w", etc.)
  [3] i1   closed   — closed flag
"""

# ─── File Struct Type ────────────────────────────────────────
"""Get or create the File struct type and register field indices."""
impl NaIRGenPass._get_file_struct_type -> ir.Type {
    if self._file_struct_type is not None {
        return self._file_struct_type;
    }
    i8p = ir.IntType(8).as_pointer();
    i1 = ir.IntType(1);
    file_struct = self.llvm_module.context.get_identified_type("File");
    file_struct.set_body(i8p, i8p, i8p, i1);
    self._file_struct_type = file_struct;
    # Register as a known struct type for method calls and field access
    self.struct_types["File"] = file_struct;
    self.struct_field_indices["File"] = {
        "handle": 0,
        "path": 1,
        "mode": 2,
        "closed": 3
    };
    self.struct_field_types["File"] = {
        "handle": i8p,
        "path": i8p,
        "mode": i8p,
        "closed": i1
    };
    self.struct_field_defaults["File"] = {};
    return file_struct;
}

# ─── File Helper Functions ───────────────────────────────────
"""Emit all File method functions as LLVM IR."""
impl NaIRGenPass._emit_file_helpers -> None {
    if self._file_helpers_emitted {
        return;
    }
    self._file_helpers_emitted = True;
    file_struct = self._get_file_struct_type();
    file_ptr_type = file_struct.as_pointer();
    i8p = ir.IntType(8).as_pointer();
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    # Declare required C functions
    fopen_fn = self._get_or_declare_extern("fopen", i8p, [i8p, i8p]);
    fclose_fn = self._get_or_declare_extern("fclose", i32, [i8p]);
    fread_fn = self._get_or_declare_extern("fread", i64, [i8p, i64, i64, i8p]);
    fwrite_fn = self._get_or_declare_extern("fwrite", i64, [i8p, i64, i64, i8p]);
    fgets_fn = self._get_or_declare_extern("fgets", i8p, [i8p, i32, i8p]);
    fflush_fn = self._get_or_declare_extern("fflush", i32, [i8p]);
    ftell_fn = self._get_or_declare_extern("ftell", i64, [i8p]);
    fseek_fn = self._get_or_declare_extern("fseek", i32, [i8p, i64, i32]);
    strlen_fn = self._get_or_declare_extern("strlen", i64, [i8p]);
    gc_malloc = self._get_or_declare_extern("GC_malloc", i8p, [i64]);
    memcpy_fn = self._get_or_declare_extern("memcpy", i8p, [i8p, i8p, i64]);
    # ── File.read(): read entire file contents as string ──
    read_fnty = ir.FunctionType(i8p, [file_ptr_type]);
    read_fn = ir.Function(self.llvm_module, read_fnty, name="File.read");
    read_fn.linkage = "private";
    read_fn.args[0].name = "self";
    bb = read_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    self_arg = read_fn.args[0];
    # Get handle
    handle_ptr = b.gep(
        self_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="handle.ptr"
    );
    handle = b.load(handle_ptr, name="handle");
    # Seek to end to get file size
    b.call(fseek_fn, [handle, ir.Constant(i64, 0), ir.Constant(i32, 2)]);  # SEEK_END = 2
    file_size = b.call(ftell_fn, [handle], name="file.size");
    b.call(fseek_fn, [handle, ir.Constant(i64, 0), ir.Constant(i32, 0)]);  # SEEK_SET = 0
    # Allocate buffer (size + 1 for null terminator)
    buf_size = b.add(file_size, ir.Constant(i64, 1), name="buf.size");
    buffer = b.call(gc_malloc, [buf_size], name="read.buf");
    # Read file contents
    bytes_read = b.call(
        fread_fn, [buffer, ir.Constant(i64, 1), file_size, handle], name="bytes.read"
    );
    # Null-terminate
    null_pos = b.gep(buffer, [bytes_read], name="null.pos");
    b.store(ir.Constant(i8, 0), null_pos);
    b.ret(buffer);
    # ── File.write(data: str) -> int: write string to file ──
    write_fnty = ir.FunctionType(i64, [file_ptr_type, i8p]);
    write_fn = ir.Function(self.llvm_module, write_fnty, name="File.write");
    write_fn.linkage = "private";
    write_fn.args[0].name = "self";
    write_fn.args[1].name = "data";
    bb = write_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    self_arg = write_fn.args[0];
    data_arg = write_fn.args[1];
    handle_ptr = b.gep(
        self_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="handle.ptr"
    );
    handle = b.load(handle_ptr, name="handle");
    # Get string length
    data_len = b.call(strlen_fn, [data_arg], name="data.len");
    # Write data
    written = b.call(
        fwrite_fn, [data_arg, ir.Constant(i64, 1), data_len, handle], name="written"
    );
    b.ret(written);
    # ── File.readline() -> str: read one line ──
    readline_fnty = ir.FunctionType(i8p, [file_ptr_type]);
    readline_fn = ir.Function(self.llvm_module, readline_fnty, name="File.readline");
    readline_fn.linkage = "private";
    readline_fn.args[0].name = "self";
    bb = readline_fn.append_basic_block("entry");
    eof_bb = readline_fn.append_basic_block("eof");
    ok_bb = readline_fn.append_basic_block("ok");
    b = ir.IRBuilder(bb);
    self_arg = readline_fn.args[0];
    handle_ptr = b.gep(
        self_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="handle.ptr"
    );
    handle = b.load(handle_ptr, name="handle");
    # Allocate stack buffer
    buf_sz = 4096;
    buf_type = ir.ArrayType(i8, buf_sz);
    buf = b.alloca(buf_type, name="line.buf");
    buf_ptr = b.bitcast(buf, i8p, name="line.ptr");
    # fgets
    result = b.call(
        fgets_fn, [buf_ptr, ir.Constant(i32, buf_sz), handle], name="fgets.result"
    );
    # Check for EOF
    null_ptr = ir.Constant(i8p, None);
    is_eof = b.icmp_signed("==", result, null_ptr, name="is.eof");
    b.cbranch(is_eof, eof_bb, ok_bb);
    # EOF: return empty string
    b.position_at_end(eof_bb);
    empty = b.call(gc_malloc, [ir.Constant(i64, 1)], name="empty.str");
    b.store(ir.Constant(i8, 0), empty);
    b.ret(empty);
    # OK: copy to GC memory
    b.position_at_end(ok_bb);
    slen = b.call(strlen_fn, [buf_ptr], name="line.len");
    alloc_size = b.add(slen, ir.Constant(i64, 1), name="alloc.size");
    line_str = b.call(gc_malloc, [alloc_size], name="line.str");
    b.call(memcpy_fn, [line_str, buf_ptr, alloc_size]);
    b.ret(line_str);
    # ── File.close(): close the file handle ──
    close_fnty = ir.FunctionType(ir.VoidType(), [file_ptr_type]);
    close_fn = ir.Function(self.llvm_module, close_fnty, name="File.close");
    close_fn.linkage = "private";
    close_fn.args[0].name = "self";
    bb = close_fn.append_basic_block("entry");
    already_closed_bb = close_fn.append_basic_block("already.closed");
    do_close_bb = close_fn.append_basic_block("do.close");
    b = ir.IRBuilder(bb);
    self_arg = close_fn.args[0];
    closed_ptr = b.gep(
        self_arg, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="closed.ptr"
    );
    is_closed = b.load(closed_ptr, name="is.closed");
    b.cbranch(is_closed, already_closed_bb, do_close_bb);
    b.position_at_end(already_closed_bb);
    b.ret_void();
    b.position_at_end(do_close_bb);
    handle_ptr = b.gep(
        self_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="handle.ptr"
    );
    handle = b.load(handle_ptr, name="handle");
    b.call(fclose_fn, [handle]);
    b.store(ir.Constant(i1, 1), closed_ptr);  # Mark as closed
    b.ret_void();
    # ── File.flush(): flush buffered data ──
    flush_fnty = ir.FunctionType(ir.VoidType(), [file_ptr_type]);
    flush_fn = ir.Function(self.llvm_module, flush_fnty, name="File.flush");
    flush_fn.linkage = "private";
    flush_fn.args[0].name = "self";
    bb = flush_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    self_arg = flush_fn.args[0];
    handle_ptr = b.gep(
        self_arg, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="handle.ptr"
    );
    handle = b.load(handle_ptr, name="handle");
    b.call(fflush_fn, [handle]);
    b.ret_void();
    # ── File.__enter__() -> File: return self for context manager ──
    enter_fnty = ir.FunctionType(file_ptr_type, [file_ptr_type]);
    enter_fn = ir.Function(self.llvm_module, enter_fnty, name="File.__enter__");
    enter_fn.linkage = "private";
    enter_fn.args[0].name = "self";
    bb = enter_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    b.ret(enter_fn.args[0]);
    # ── File.__exit__(exc_type, exc_val, tb) -> bool: close if not closed ──
    exit_fnty = ir.FunctionType(i1, [file_ptr_type, i8p, i8p, i8p]);
    exit_fn = ir.Function(self.llvm_module, exit_fnty, name="File.__exit__");
    exit_fn.linkage = "private";
    exit_fn.args[0].name = "self";
    exit_fn.args[1].name = "exc_type";
    exit_fn.args[2].name = "exc_val";
    exit_fn.args[3].name = "traceback";
    bb = exit_fn.append_basic_block("entry");
    b = ir.IRBuilder(bb);
    self_arg = exit_fn.args[0];
    # Call close on self
    b.call(close_fn, [self_arg]);
    # Return False (don't suppress exceptions)
    b.ret(ir.Constant(i1, 0));
    # Register all methods in method_funcs
    self.method_funcs["File.read"] = read_fn;
    self.method_funcs["File.write"] = write_fn;
    self.method_funcs["File.readline"] = readline_fn;
    self.method_funcs["File.close"] = close_fn;
    self.method_funcs["File.flush"] = flush_fn;
    self.method_funcs["File.__enter__"] = enter_fn;
    self.method_funcs["File.__exit__"] = exit_fn;
    # Also register in func_symtab for lookup
    self.func_symtab["File.read"] = read_fn;
    self.func_symtab["File.write"] = write_fn;
    self.func_symtab["File.readline"] = readline_fn;
    self.func_symtab["File.close"] = close_fn;
    self.func_symtab["File.flush"] = flush_fn;
    self.func_symtab["File.__enter__"] = enter_fn;
    self.func_symtab["File.__exit__"] = exit_fn;
}

# ─── open() Builtin ─────────────────────────────────────────
"""Emit code for open(path, mode) builtin: allocate File struct, call fopen."""
impl NaIRGenPass._emit_open(node: uni.FuncCall) -> (ir.Value | None) {
    i8p = ir.IntType(8).as_pointer();
    i8 = ir.IntType(8);
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    i1 = ir.IntType(1);
    # Ensure File type and helpers are emitted
    file_struct = self._get_file_struct_type();
    self._emit_file_helpers();
    file_ptr_type = file_struct.as_pointer();
    # Get arguments: path (required), mode (optional, default "r")
    params = node.params or [];
    if not params {
        return None;
    }
    path_val = self._codegen_expr(params[0]);
    if path_val is None {
        return None;
    }
    mode_val: (ir.Value | None) = None;
    if len(params) >= 2 {
        mode_val = self._codegen_expr(params[1]);
    }
    if mode_val is None {
        mode_val = self._make_global_string("r", name_prefix=".file.mode");
    }
    # Call fopen(path, mode)
    fopen_fn = self._get_or_declare_extern("fopen", i8p, [i8p, i8p]);
    file_handle = self.builder.call(
        fopen_fn, [path_val, mode_val], name="fopen.result"
    );
    # Check for NULL (file open failure)
    func = self.builder.function;
    null_bb = func.append_basic_block(name="open.null");
    ok_bb = func.append_basic_block(name="open.ok");
    merge_bb = func.append_basic_block(name="open.merge");
    null_ptr = ir.Constant(i8p, None);
    is_null = self.builder.icmp_signed("==", file_handle, null_ptr, name="fopen.null");
    self.builder.cbranch(is_null, null_bb, ok_bb);
    # NULL path: return null File pointer
    self.builder.position_at_end(null_bb);
    null_file = ir.Constant(file_ptr_type, None);
    self.builder.branch(merge_bb);
    null_bb_end = self.builder.block;
    # OK path: allocate and initialize File struct
    self.builder.position_at_end(ok_bb);
    gc_malloc = self._get_or_declare_extern("GC_malloc", i8p, [i64]);
    # Compute sizeof(File) using GEP-from-null trick
    null_file_ptr = ir.Constant(file_ptr_type, None);
    size_gep = self.builder.gep(
        null_file_ptr, [ir.Constant(i32, 1)], name="file.sizeof"
    );
    file_size = self.builder.ptrtoint(size_gep, i64, name="file.size");
    # Allocate
    raw = self.builder.call(gc_malloc, [file_size], name="file.raw");
    file_obj = self.builder.bitcast(raw, file_ptr_type, name="file.obj");
    # Store fields
    # handle
    handle_ptr = self.builder.gep(
        file_obj, [ir.Constant(i32, 0), ir.Constant(i32, 0)], name="file.handle.ptr"
    );
    self.builder.store(file_handle, handle_ptr);
    # path
    path_ptr = self.builder.gep(
        file_obj, [ir.Constant(i32, 0), ir.Constant(i32, 1)], name="file.path.ptr"
    );
    self.builder.store(path_val, path_ptr);
    # mode
    mode_ptr = self.builder.gep(
        file_obj, [ir.Constant(i32, 0), ir.Constant(i32, 2)], name="file.mode.ptr"
    );
    self.builder.store(mode_val, mode_ptr);
    # closed = false
    closed_ptr = self.builder.gep(
        file_obj, [ir.Constant(i32, 0), ir.Constant(i32, 3)], name="file.closed.ptr"
    );
    self.builder.store(ir.Constant(i1, 0), closed_ptr);
    self.builder.branch(merge_bb);
    ok_bb_end = self.builder.block;
    # Merge with phi
    self.builder.position_at_end(merge_bb);
    phi = self.builder.phi(file_ptr_type, name="open.result");
    phi.add_incoming(null_file, null_bb_end);
    phi.add_incoming(file_obj, ok_bb_end);
    return phi;
}

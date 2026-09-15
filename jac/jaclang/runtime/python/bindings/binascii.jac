"""Binary codec signatures, exported-buffer ownership, and interpreter state."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_state_owned,
    jacpy_binding_exception,
    jacpy_binding_state_get
}
import from jaclang.runtime.python.bindings.arguments {
    CallSignature,
    BoundArguments,
    invoke
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.modules.binascii { jacpy_binascii_convert }
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_truth,
    jacpy_error_pending,
    jacpy_object_size,
    jacpy_is_unicode,
    jacpy_is_bytes,
    jacpy_buffer_byte,
    jacpy_long_as_int32,
    object_error
}
import from c {
    def jacpy_unsigned_mask(value: u64) -> u64;  def jacpy_unicode_read(
        value: u64, index: i64
    ) -> i64;
}

def:priv convert(module: u64, data: u64, operation: int, options: list[u64]) -> u64 {
    view = BufferArgument();
    if not view.acquire(data, operation in [0, 2, 4, 6]) {
        return 0;
    }
    option: i64 = 0;
    second: i64 = 0;
    third: i64 = 0;
    if operation in [1, 2, 3, 6, 7] {
        flags: list[i64] = [1 if operation == 3 else 0, 1 if operation == 7 else 0, 0];
        for i in range(len(options)) {
            if options[i] != 0 {
                flags[i] = jacpy_truth(options[i]);
                if flags[i] < 0 {
                    return 0;
                }
            }
        }
        option = flags[0];
        second = flags[1];
        third = flags[2];
    } elif operation == 5 {
        option = -1;
        second = 1;
        separator = options[0];
        if separator != 0 {
            size = jacpy_object_size(separator);
            if size < 0 {
                return 0;
            }
            if size != 1 {
                object_error("ValueError", "sep must be length 1.");
                return 0;
            }
            if jacpy_is_unicode(separator) != 0 {
                option = jacpy_unicode_read(separator, 0);
                if option > 255 {
                    object_error("ValueError", "sep must be ASCII.");
                    return 0;
                }
            } elif jacpy_is_bytes(separator) != 0 {
                option = jacpy_buffer_byte(separator, 0);
            } else {
                object_error("TypeError", "sep must be str or bytes.");
                return 0;
            }
        }
        if options[1] != 0 {
            second = jacpy_long_as_int32(options[1]);
            if jacpy_error_pending() != 0 {
                return 0;
            }
        }
    } elif operation in [8, 9] {
        if options[0] != 0 {
            option = i64(jacpy_unsigned_mask(options[0]) & u64(0xffffffff));
            if jacpy_error_pending() != 0 {
                return 0;
            }
        }
    }
    source = view.bytes();
    if source == 0 {
        return 0;
    }
    result = jacpy_binascii_convert(
        source,
        jacpy_binding_state_get(module, 0),
        i64(operation),
        option,
        second,
        third
    );
    jacpy_release(source);
    return result;
}

def:priv a2b_uu_call(module: u64, data: u64) -> u64 {
    return convert(module, data, 0, []);
}

def:priv a2b_hex_call(module: u64, data: u64) -> u64 {
    return convert(module, data, 4, []);
}

def:priv unhexlify_call(module: u64, data: u64) -> u64 {
    return convert(module, data, 4, []);
}

glob:priv b2a_uu_signature = CallSignature(
         "b2a_uu", ["data", "backtick"], 1, 1, 1
     );

def:priv b2a_uu_bound(args: BoundArguments) -> u64 {
    return convert(args.context, args.values[0], 1, [args.values[1]]);
}

def:priv b2a_uu_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(b2a_uu_signature, args, kwargs, b2a_uu_bound, module);
}

glob:priv a2b_base64_signature = CallSignature(
         "a2b_base64", ["data", "strict_mode"], 1, 1, 1
     );

def:priv a2b_base64_bound(args: BoundArguments) -> u64 {
    return convert(args.context, args.values[0], 2, [args.values[1]]);
}

def:priv a2b_base64_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(a2b_base64_signature, args, kwargs, a2b_base64_bound, module);
}

glob:priv b2a_base64_signature = CallSignature(
         "b2a_base64", ["data", "newline"], 1, 1, 1
     );

def:priv b2a_base64_bound(args: BoundArguments) -> u64 {
    return convert(args.context, args.values[0], 3, [args.values[1]]);
}

def:priv b2a_base64_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(b2a_base64_signature, args, kwargs, b2a_base64_bound, module);
}

glob:priv b2a_hex_signature = CallSignature(
         "b2a_hex", ["data", "sep", "bytes_per_sep"], 1, 3, 0
     );

def:priv b2a_hex_bound(args: BoundArguments) -> u64 {
    return convert(args.context, args.values[0], 5, [args.values[1], args.values[2]]);
}

def:priv b2a_hex_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(b2a_hex_signature, args, kwargs, b2a_hex_bound, module);
}

glob:priv hexlify_signature = CallSignature(
         "hexlify", ["data", "sep", "bytes_per_sep"], 1, 3, 0
     );

def:priv hexlify_bound(args: BoundArguments) -> u64 {
    return convert(args.context, args.values[0], 5, [args.values[1], args.values[2]]);
}

def:priv hexlify_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(hexlify_signature, args, kwargs, hexlify_bound, module);
}

glob:priv a2b_qp_signature = CallSignature("a2b_qp", ["data", "header"], 1, 2, 0);
def:priv a2b_qp_bound(args: BoundArguments) -> u64 {
    return convert(args.context, args.values[0], 6, [args.values[1]]);
}

def:priv a2b_qp_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(a2b_qp_signature, args, kwargs, a2b_qp_bound, module);
}

glob:priv b2a_qp_signature = CallSignature(
         "b2a_qp", ["data", "quotetabs", "istext", "header"], 1, 4, 0
     );

def:priv b2a_qp_bound(args: BoundArguments) -> u64 {
    return convert(
        args.context,
        args.values[0],
        7,
        [args.values[1], args.values[2], args.values[3]]
    );
}

def:priv b2a_qp_call(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(b2a_qp_signature, args, kwargs, b2a_qp_bound, module);
}

glob:priv crc_hqx_signature = CallSignature("crc_hqx", ["data", "crc"], 2, 2, 2);
def:priv crc_hqx_bound(args: BoundArguments) -> u64 {
    return convert(args.context, args.values[0], 8, [args.values[1]]);
}

def:priv crc_hqx_call(module: u64, args: u64) -> u64 {
    return invoke(crc_hqx_signature, args, 0, crc_hqx_bound, module);
}

glob:priv crc32_signature = CallSignature("crc32", ["data", "crc"], 1, 2, 2);
def:priv crc32_bound(args: BoundArguments) -> u64 {
    return convert(args.context, args.values[0], 9, [args.values[1]]);
}

def:priv crc32_call(module: u64, args: u64) -> u64 {
    return invoke(crc32_signature, args, 0, crc32_bound, module);
}

def:priv execute(module: u64) -> i32 {
    if not add_state_owned(
        module, 0, "Error", jacpy_binding_exception("binascii.Error", "ValueError", "")
    ) {
        return i32(-1);
    }
    if not add_state_owned(
        module, 1, "Incomplete", jacpy_binding_exception("binascii.Incomplete", "", "")
    ) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "binascii",
         "Binary codecs implemented in native Jac.",
         [
             MethodDefinition(
                 "a2b_uu",
                 MethodCallbacks(positional=a2b_uu_call),
                 "a2b_uu($module, data, /)\n--\n\nDecode a uuencoded line.",
                 flags=8
             ),
             MethodDefinition(
                 "a2b_hex",
                 MethodCallbacks(positional=a2b_hex_call),
                 "a2b_hex($module, hexstr, /)\n--\n\nDecode hexadecimal data.",
                 flags=8
             ),
             MethodDefinition(
                 "unhexlify",
                 MethodCallbacks(positional=unhexlify_call),
                 "unhexlify($module, hexstr, /)\n--\n\nDecode hexadecimal data.",
                 flags=8
             ),
             MethodDefinition(
                 "b2a_uu",
                 MethodCallbacks(keywords=b2a_uu_call),
                 "b2a_uu($module, data, /, *, backtick=False)\n--\n\nConvert binary data."
             ),
             MethodDefinition(
                 "a2b_base64",
                 MethodCallbacks(keywords=a2b_base64_call),
                 "a2b_base64($module, data, /, *, strict_mode=False)\n--\n\nConvert binary data."
             ),
             MethodDefinition(
                 "b2a_base64",
                 MethodCallbacks(keywords=b2a_base64_call),
                 "b2a_base64($module, data, /, *, newline=True)\n--\n\nConvert binary data."
             ),
             MethodDefinition(
                 "b2a_hex",
                 MethodCallbacks(keywords=b2a_hex_call),
                 "b2a_hex($module, /, data, sep=<unrepresentable>, bytes_per_sep=1)\n--\n\nConvert binary data."
             ),
             MethodDefinition(
                 "hexlify",
                 MethodCallbacks(keywords=hexlify_call),
                 "hexlify($module, /, data, sep=<unrepresentable>, bytes_per_sep=1)\n--\n\nConvert binary data."
             ),
             MethodDefinition(
                 "a2b_qp",
                 MethodCallbacks(keywords=a2b_qp_call),
                 "a2b_qp($module, /, data, header=False)\n--\n\nConvert binary data."
             ),
             MethodDefinition(
                 "b2a_qp",
                 MethodCallbacks(keywords=b2a_qp_call),
                 "b2a_qp($module, /, data, quotetabs=False, istext=True, header=False)\n--\n\nConvert binary data."
             ),
             MethodDefinition(
                 "crc_hqx",
                 MethodCallbacks(positional=crc_hqx_call),
                 "crc_hqx($module, data, crc, /)\n--\n\nCompute CRC.",
                 flags=1
             ),
             MethodDefinition(
                 "crc32",
                 MethodCallbacks(positional=crc32_call),
                 "crc32($module, data, crc=0, /)\n--\n\nCompute CRC.",
                 flags=1
             )
         ],
         ModuleHooks(execute=execute),
         2
     );

def:pub PyInit_binascii -> u64 {
    return definition.initialize();
}

"""Python operator bindings and native accessor state."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_owned
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyDefinition,
    jacpy_binding_allocate,
    jacpy_binding_typeof
}
import from jaclang.runtime.python.bindings.payload {
    jacpy_binding_native_get,
    jacpy_binding_native_set,
    jacpy_binding_native_present,
    dispose_payload,
    clear_payload,
    traverse_payload
}
import from jaclang.runtime.python.bindings.references { ReferenceState }
import from jaclang.runtime.python.bindings.arguments {
    BoundArguments,
    CallSignature,
    invoke,
    invoke_one,
    index_value
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_retain,
    jacpy_tuple_size,
    jacpy_dict_size,
    jacpy_is_unicode,
    object_error,
    type_name,
    text_object,
    boundary_failure
}
import from c {
    def jacpy_binding_vector_count(count: u64) -> i64;  def jacpy_binding_vector_item(
        arguments: u64, index: i64
    ) -> u64;  def jacpy_buffer_supported(value: u64) -> i64;  def jacpy_unicode_ascii(
        value: u64
    ) -> i64;
}
import from jaclang.runtime.python.modules.operator {
    jacpy_operator_neg,
    jacpy_operator_pos,
    jacpy_operator_abs,
    jacpy_operator_invert,
    jacpy_operator_index,
    jacpy_operator_truth,
    jacpy_operator_not_,
    jacpy_operator_is_none,
    jacpy_operator_is_not_none,
    jacpy_operator_add,
    jacpy_operator_sub,
    jacpy_operator_mul,
    jacpy_operator_matmul,
    jacpy_operator_floordiv,
    jacpy_operator_truediv,
    jacpy_operator_mod,
    jacpy_operator_lshift,
    jacpy_operator_rshift,
    jacpy_operator_and_,
    jacpy_operator_xor,
    jacpy_operator_or_,
    jacpy_operator_iadd,
    jacpy_operator_isub,
    jacpy_operator_imul,
    jacpy_operator_imatmul,
    jacpy_operator_ifloordiv,
    jacpy_operator_itruediv,
    jacpy_operator_imod,
    jacpy_operator_ilshift,
    jacpy_operator_irshift,
    jacpy_operator_iand,
    jacpy_operator_ixor,
    jacpy_operator_ior,
    jacpy_operator_concat,
    jacpy_operator_iconcat,
    jacpy_operator_getitem,
    jacpy_operator_is_,
    jacpy_operator_is_not,
    jacpy_operator_pow,
    jacpy_operator_ipow,
    jacpy_operator_contains,
    jacpy_operator_indexOf,
    jacpy_operator_countOf,
    jacpy_operator_delitem,
    jacpy_operator_compare,
    jacpy_operator_setitem,
    jacpy_operator_length_hint,
    jacpy_operator_call,
    jacpy_operator_digest,
    jacpy_operator_prepare,
    jacpy_operator_apply,
    jacpy_operator_repr,
    jacpy_operator_reduce
}

def:priv neg_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, jacpy_operator_neg);
}

def:priv pos_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, jacpy_operator_pos);
}

def:priv abs_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, jacpy_operator_abs);
}

def:priv invert_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, jacpy_operator_invert);
}

def:priv index_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, jacpy_operator_index);
}

def:priv truth_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, jacpy_operator_truth);
}

def:priv not__call(module: u64, value: u64) -> u64 {
    return invoke_one(value, jacpy_operator_not_);
}

def:priv is_none_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, jacpy_operator_is_none);
}

def:priv is_not_none_call(module: u64, value: u64) -> u64 {
    return invoke_one(value, jacpy_operator_is_not_none);
}

glob:priv add_signature = CallSignature("add", ["a", "b"], 2, 2, 2);
def:priv add_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_add(args.values[0], args.values[1]);
}

def:priv add_call(module: u64, args: u64) -> u64 {
    return invoke(add_signature, args, 0, add_bound);
}

glob:priv sub_signature = CallSignature("sub", ["a", "b"], 2, 2, 2);
def:priv sub_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_sub(args.values[0], args.values[1]);
}

def:priv sub_call(module: u64, args: u64) -> u64 {
    return invoke(sub_signature, args, 0, sub_bound);
}

glob:priv mul_signature = CallSignature("mul", ["a", "b"], 2, 2, 2);
def:priv mul_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_mul(args.values[0], args.values[1]);
}

def:priv mul_call(module: u64, args: u64) -> u64 {
    return invoke(mul_signature, args, 0, mul_bound);
}

glob:priv matmul_signature = CallSignature("matmul", ["a", "b"], 2, 2, 2);
def:priv matmul_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_matmul(args.values[0], args.values[1]);
}

def:priv matmul_call(module: u64, args: u64) -> u64 {
    return invoke(matmul_signature, args, 0, matmul_bound);
}

glob:priv floordiv_signature = CallSignature("floordiv", ["a", "b"], 2, 2, 2);
def:priv floordiv_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_floordiv(args.values[0], args.values[1]);
}

def:priv floordiv_call(module: u64, args: u64) -> u64 {
    return invoke(floordiv_signature, args, 0, floordiv_bound);
}

glob:priv truediv_signature = CallSignature("truediv", ["a", "b"], 2, 2, 2);
def:priv truediv_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_truediv(args.values[0], args.values[1]);
}

def:priv truediv_call(module: u64, args: u64) -> u64 {
    return invoke(truediv_signature, args, 0, truediv_bound);
}

glob:priv mod_signature = CallSignature("mod", ["a", "b"], 2, 2, 2);
def:priv mod_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_mod(args.values[0], args.values[1]);
}

def:priv mod_call(module: u64, args: u64) -> u64 {
    return invoke(mod_signature, args, 0, mod_bound);
}

glob:priv lshift_signature = CallSignature("lshift", ["a", "b"], 2, 2, 2);
def:priv lshift_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_lshift(args.values[0], args.values[1]);
}

def:priv lshift_call(module: u64, args: u64) -> u64 {
    return invoke(lshift_signature, args, 0, lshift_bound);
}

glob:priv rshift_signature = CallSignature("rshift", ["a", "b"], 2, 2, 2);
def:priv rshift_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_rshift(args.values[0], args.values[1]);
}

def:priv rshift_call(module: u64, args: u64) -> u64 {
    return invoke(rshift_signature, args, 0, rshift_bound);
}

glob:priv and__signature = CallSignature("and_", ["a", "b"], 2, 2, 2);
def:priv and__bound(args: BoundArguments) -> u64 {
    return jacpy_operator_and_(args.values[0], args.values[1]);
}

def:priv and__call(module: u64, args: u64) -> u64 {
    return invoke(and__signature, args, 0, and__bound);
}

glob:priv xor_signature = CallSignature("xor", ["a", "b"], 2, 2, 2);
def:priv xor_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_xor(args.values[0], args.values[1]);
}

def:priv xor_call(module: u64, args: u64) -> u64 {
    return invoke(xor_signature, args, 0, xor_bound);
}

glob:priv or__signature = CallSignature("or_", ["a", "b"], 2, 2, 2);
def:priv or__bound(args: BoundArguments) -> u64 {
    return jacpy_operator_or_(args.values[0], args.values[1]);
}

def:priv or__call(module: u64, args: u64) -> u64 {
    return invoke(or__signature, args, 0, or__bound);
}

glob:priv iadd_signature = CallSignature("iadd", ["a", "b"], 2, 2, 2);
def:priv iadd_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_iadd(args.values[0], args.values[1]);
}

def:priv iadd_call(module: u64, args: u64) -> u64 {
    return invoke(iadd_signature, args, 0, iadd_bound);
}

glob:priv isub_signature = CallSignature("isub", ["a", "b"], 2, 2, 2);
def:priv isub_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_isub(args.values[0], args.values[1]);
}

def:priv isub_call(module: u64, args: u64) -> u64 {
    return invoke(isub_signature, args, 0, isub_bound);
}

glob:priv imul_signature = CallSignature("imul", ["a", "b"], 2, 2, 2);
def:priv imul_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_imul(args.values[0], args.values[1]);
}

def:priv imul_call(module: u64, args: u64) -> u64 {
    return invoke(imul_signature, args, 0, imul_bound);
}

glob:priv imatmul_signature = CallSignature("imatmul", ["a", "b"], 2, 2, 2);
def:priv imatmul_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_imatmul(args.values[0], args.values[1]);
}

def:priv imatmul_call(module: u64, args: u64) -> u64 {
    return invoke(imatmul_signature, args, 0, imatmul_bound);
}

glob:priv ifloordiv_signature = CallSignature("ifloordiv", ["a", "b"], 2, 2, 2);
def:priv ifloordiv_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_ifloordiv(args.values[0], args.values[1]);
}

def:priv ifloordiv_call(module: u64, args: u64) -> u64 {
    return invoke(ifloordiv_signature, args, 0, ifloordiv_bound);
}

glob:priv itruediv_signature = CallSignature("itruediv", ["a", "b"], 2, 2, 2);
def:priv itruediv_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_itruediv(args.values[0], args.values[1]);
}

def:priv itruediv_call(module: u64, args: u64) -> u64 {
    return invoke(itruediv_signature, args, 0, itruediv_bound);
}

glob:priv imod_signature = CallSignature("imod", ["a", "b"], 2, 2, 2);
def:priv imod_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_imod(args.values[0], args.values[1]);
}

def:priv imod_call(module: u64, args: u64) -> u64 {
    return invoke(imod_signature, args, 0, imod_bound);
}

glob:priv ilshift_signature = CallSignature("ilshift", ["a", "b"], 2, 2, 2);
def:priv ilshift_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_ilshift(args.values[0], args.values[1]);
}

def:priv ilshift_call(module: u64, args: u64) -> u64 {
    return invoke(ilshift_signature, args, 0, ilshift_bound);
}

glob:priv irshift_signature = CallSignature("irshift", ["a", "b"], 2, 2, 2);
def:priv irshift_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_irshift(args.values[0], args.values[1]);
}

def:priv irshift_call(module: u64, args: u64) -> u64 {
    return invoke(irshift_signature, args, 0, irshift_bound);
}

glob:priv iand_signature = CallSignature("iand", ["a", "b"], 2, 2, 2);
def:priv iand_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_iand(args.values[0], args.values[1]);
}

def:priv iand_call(module: u64, args: u64) -> u64 {
    return invoke(iand_signature, args, 0, iand_bound);
}

glob:priv ixor_signature = CallSignature("ixor", ["a", "b"], 2, 2, 2);
def:priv ixor_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_ixor(args.values[0], args.values[1]);
}

def:priv ixor_call(module: u64, args: u64) -> u64 {
    return invoke(ixor_signature, args, 0, ixor_bound);
}

glob:priv ior_signature = CallSignature("ior", ["a", "b"], 2, 2, 2);
def:priv ior_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_ior(args.values[0], args.values[1]);
}

def:priv ior_call(module: u64, args: u64) -> u64 {
    return invoke(ior_signature, args, 0, ior_bound);
}

glob:priv concat_signature = CallSignature("concat", ["a", "b"], 2, 2, 2);
def:priv concat_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_concat(args.values[0], args.values[1]);
}

def:priv concat_call(module: u64, args: u64) -> u64 {
    return invoke(concat_signature, args, 0, concat_bound);
}

glob:priv iconcat_signature = CallSignature("iconcat", ["a", "b"], 2, 2, 2);
def:priv iconcat_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_iconcat(args.values[0], args.values[1]);
}

def:priv iconcat_call(module: u64, args: u64) -> u64 {
    return invoke(iconcat_signature, args, 0, iconcat_bound);
}

glob:priv getitem_signature = CallSignature("getitem", ["a", "b"], 2, 2, 2);
def:priv getitem_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_getitem(args.values[0], args.values[1]);
}

def:priv getitem_call(module: u64, args: u64) -> u64 {
    return invoke(getitem_signature, args, 0, getitem_bound);
}

glob:priv is__signature = CallSignature("is_", ["a", "b"], 2, 2, 2);
def:priv is__bound(args: BoundArguments) -> u64 {
    return jacpy_operator_is_(args.values[0], args.values[1]);
}

def:priv is__call(module: u64, args: u64) -> u64 {
    return invoke(is__signature, args, 0, is__bound);
}

glob:priv is_not_signature = CallSignature("is_not", ["a", "b"], 2, 2, 2);
def:priv is_not_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_is_not(args.values[0], args.values[1]);
}

def:priv is_not_call(module: u64, args: u64) -> u64 {
    return invoke(is_not_signature, args, 0, is_not_bound);
}

glob:priv pow_signature = CallSignature("pow", ["a", "b"], 2, 2, 2);
def:priv pow_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_pow(args.values[0], args.values[1]);
}

def:priv pow_call(module: u64, args: u64) -> u64 {
    return invoke(pow_signature, args, 0, pow_bound);
}

glob:priv ipow_signature = CallSignature("ipow", ["a", "b"], 2, 2, 2);
def:priv ipow_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_ipow(args.values[0], args.values[1]);
}

def:priv ipow_call(module: u64, args: u64) -> u64 {
    return invoke(ipow_signature, args, 0, ipow_bound);
}

glob:priv contains_signature = CallSignature("contains", ["a", "b"], 2, 2, 2);
def:priv contains_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_contains(args.values[0], args.values[1]);
}

def:priv contains_call(module: u64, args: u64) -> u64 {
    return invoke(contains_signature, args, 0, contains_bound);
}

glob:priv indexOf_signature = CallSignature("indexOf", ["a", "b"], 2, 2, 2);
def:priv indexOf_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_indexOf(args.values[0], args.values[1]);
}

def:priv indexOf_call(module: u64, args: u64) -> u64 {
    return invoke(indexOf_signature, args, 0, indexOf_bound);
}

glob:priv countOf_signature = CallSignature("countOf", ["a", "b"], 2, 2, 2);
def:priv countOf_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_countOf(args.values[0], args.values[1]);
}

def:priv countOf_call(module: u64, args: u64) -> u64 {
    return invoke(countOf_signature, args, 0, countOf_bound);
}

glob:priv delitem_signature = CallSignature("delitem", ["a", "b"], 2, 2, 2);
def:priv delitem_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_delitem(args.values[0], args.values[1]);
}

def:priv delitem_call(module: u64, args: u64) -> u64 {
    return invoke(delitem_signature, args, 0, delitem_bound);
}

glob:priv lt_signature = CallSignature("lt", ["a", "b"], 2, 2, 2);
def:priv lt_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(0));
}

def:priv lt_call(module: u64, args: u64) -> u64 {
    return invoke(lt_signature, args, 0, lt_bound);
}

glob:priv le_signature = CallSignature("le", ["a", "b"], 2, 2, 2);
def:priv le_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(1));
}

def:priv le_call(module: u64, args: u64) -> u64 {
    return invoke(le_signature, args, 0, le_bound);
}

glob:priv eq_signature = CallSignature("eq", ["a", "b"], 2, 2, 2);
def:priv eq_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(2));
}

def:priv eq_call(module: u64, args: u64) -> u64 {
    return invoke(eq_signature, args, 0, eq_bound);
}

glob:priv ne_signature = CallSignature("ne", ["a", "b"], 2, 2, 2);
def:priv ne_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(3));
}

def:priv ne_call(module: u64, args: u64) -> u64 {
    return invoke(ne_signature, args, 0, ne_bound);
}

glob:priv gt_signature = CallSignature("gt", ["a", "b"], 2, 2, 2);
def:priv gt_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(4));
}

def:priv gt_call(module: u64, args: u64) -> u64 {
    return invoke(gt_signature, args, 0, gt_bound);
}

glob:priv ge_signature = CallSignature("ge", ["a", "b"], 2, 2, 2);
def:priv ge_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(5));
}

def:priv ge_call(module: u64, args: u64) -> u64 {
    return invoke(ge_signature, args, 0, ge_bound);
}

glob:priv setitem_signature = CallSignature("setitem", ["a", "b", "c"], 3, 3, 3),
     length_hint_signature = CallSignature("length_hint", ["obj", "default"], 1, 2, 2),
     digest_signature = CallSignature("_compare_digest", ["a", "b"], 2, 2, 2);

def:priv setitem_bound(args: BoundArguments) -> u64 {
    return jacpy_operator_setitem(args.values[0], args.values[1], args.values[2]);
}

def:priv setitem_call(module: u64, args: u64) -> u64 {
    return invoke(setitem_signature, args, 0, setitem_bound);
}

def:priv length_hint_bound(args: BoundArguments) -> u64 {
    fallback: i64 = 0;
    if args.values[1] != 0 {
        value = index_value(args.values[1]);
        if value is None {
            return 0;
        }
        fallback = value;
    }
    return jacpy_operator_length_hint(args.values[0], fallback);
}

def:priv length_hint_call(module: u64, args: u64) -> u64 {
    return invoke(length_hint_signature, args, 0, length_hint_bound);
}

def:priv call_call(module: u64, args: u64, kwargs: u64) -> u64 {
    if jacpy_tuple_size(args) == 0 {
        object_error("TypeError", "call expected at least 1 argument, got 0");
        return 0;
    }
    return jacpy_operator_call(args, kwargs);
}

def:priv digest_bound(args: BoundArguments) -> u64 {
    a = args.values[0];
    b = args.values[1];
    ascii = jacpy_is_unicode(a) != 0 and jacpy_is_unicode(b) != 0;
    if ascii {
        if jacpy_unicode_ascii(a) == 0 or jacpy_unicode_ascii(b) == 0 {
            object_error(
                "TypeError",
                "comparing strings with non-ASCII characters is not supported"
            );
            return 0;
        }
    } elif jacpy_buffer_supported(a) == 0 and jacpy_buffer_supported(b) == 0 {
        object_error(
            "TypeError",
            f"unsupported operand types(s) or combination of types: '{type_name(a)[:100]}' and '{type_name(
                b
            )[:100]}'"
        );
        return 0;
    }
    av = BufferArgument();
    bv = BufferArgument();
    if not av.acquire(a, ascii) {
        return 0;
    }
    if av.dimensions() > 1 {
        object_error("BufferError", "Buffer must be single dimension");
        return 0;
    }
    if not bv.acquire(b, ascii) {
        return 0;
    }
    if bv.dimensions() > 1 {
        object_error("BufferError", "Buffer must be single dimension");
        return 0;
    }
    return jacpy_operator_digest(av.address(), bv.address(), av.size(), bv.size());
}

def:priv digest_call(module: u64, args: u64) -> u64 {
    return invoke(digest_signature, args, 0, digest_bound);
}

obj AccessorState(ReferenceState) {
    has kind: i64;
}

def:priv accessor_state(instance: u64, definition: u64) -> (AccessorState | None) {
    if jacpy_binding_native_present(instance, definition) != 0 {
        state = jacpy_binding_native_get(instance, definition);
        if isinstance(state, AccessorState) {
            return state;
        }
    }
    object_error("SystemError", "native accessor state is unavailable");
    return None;
}

def:priv accessor_create(
    type: u64, args: u64, kwargs: u64, definition: u64, kind: i64
) -> u64 {
    if kind != 2 and jacpy_dict_size(kwargs) != 0 {
        object_error(
            "TypeError", f"{type_name(type, True)}() takes no keyword arguments"
        );
        return 0;
    }
    if jacpy_tuple_size(args) < 1 {
        object_error(
            "TypeError", f"{type_name(type, True)} expected at least 1 argument, got 0"
        );
        return 0;
    }
    prepared = jacpy_operator_prepare(kind, args);
    if prepared == 0 {
        return 0;
    }
    state = AccessorState(
        references=[prepared, jacpy_retain(kwargs) if kwargs != 0 else u64(0)],
        kind=kind
    );
    instance = jacpy_binding_allocate(type);
    if instance == 0 {
        return 0;
    }
    if jacpy_binding_native_set(instance, definition, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv accessor_vector(
    instance: u64, args: u64, count: u64, names: u64, definition: u64
) -> u64 {
    if names != 0 and jacpy_tuple_size(names) != 0 {
        object_error(
            "TypeError", f"{type_name(instance)}() takes no keyword arguments"
        );
        return 0;
    }
    size = jacpy_binding_vector_count(count);
    if size != 1 {
        object_error(
            "TypeError", f"{type_name(instance)} expected 1 argument, got {size}"
        );
        return 0;
    }
    state = accessor_state(instance, definition);
    if state is None {
        return 0;
    }
    return jacpy_operator_apply(
        state.kind,
        jacpy_binding_vector_item(args, 0),
        state.references[0],
        state.references[1]
    );
}

def:priv accessor_repr(instance: u64, definition: u64) -> u64 {
    state = accessor_state(instance, definition);
    if state is None {
        return 0;
    }
    return jacpy_operator_repr(
        state.kind, instance, state.references[0], state.references[1]
    );
}

def:priv accessor_reduce(instance: u64, definition: u64) -> u64 {
    state = accessor_state(instance, definition);
    if state is None {
        return 0;
    }
    return jacpy_operator_reduce(
        state.kind,
        jacpy_binding_typeof(instance),
        state.references[0],
        state.references[1]
    );
}

def:priv accessor_signature(instance: u64, context: u64) -> u64 {
    try {
        return text_object("(obj, /)");
    } except boundary_failure {
        return 0;
    }
}

def:priv itemgetter_create(type: u64, args: u64, kwargs: u64) -> u64 {
    return accessor_create(type, args, kwargs, itemgetter_type.handle, i64(0));
}

def:priv itemgetter_vector(instance: u64, args: u64, count: u64, names: u64) -> u64 {
    return accessor_vector(instance, args, count, names, itemgetter_type.handle);
}

def:priv itemgetter_repr(instance: u64) -> u64 {
    return accessor_repr(instance, itemgetter_type.handle);
}

def:priv itemgetter_reduce(instance: u64, unused: u64) -> u64 {
    return accessor_reduce(instance, itemgetter_type.handle);
}

def:priv itemgetter_clear(instance: u64) -> i32 {
    return clear_payload(instance, itemgetter_type.handle);
}

def:priv itemgetter_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, itemgetter_type.handle, visitor, context);
}

def:priv itemgetter_deallocate(instance: u64) {
    dispose_payload(instance, itemgetter_type.handle);
}

glob:priv itemgetter_type = TypeDefinition(
         "operator.itemgetter",
         "itemgetter(item, /, *items)\n--\n\nFetch items from an operand.",
         [
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=itemgetter_reduce),
                 "Return state for pickling.",
                 flags=4
             )
         ],
         u64(
             TypeFlags.GC.value | TypeFlags.IMMUTABLE.value | TypeFlags.VECTORCALL.value
         ),
         TypeHooks(
             create=itemgetter_create,
             vectorcall=itemgetter_vector,
             repr=itemgetter_repr,
             clear=itemgetter_clear,
             traverse=itemgetter_traverse,
             dealloc=itemgetter_deallocate
         ),
         [PropertyDefinition("__text_signature__", accessor_signature)]
     );

def:priv attrgetter_create(type: u64, args: u64, kwargs: u64) -> u64 {
    return accessor_create(type, args, kwargs, attrgetter_type.handle, i64(1));
}

def:priv attrgetter_vector(instance: u64, args: u64, count: u64, names: u64) -> u64 {
    return accessor_vector(instance, args, count, names, attrgetter_type.handle);
}

def:priv attrgetter_repr(instance: u64) -> u64 {
    return accessor_repr(instance, attrgetter_type.handle);
}

def:priv attrgetter_reduce(instance: u64, unused: u64) -> u64 {
    return accessor_reduce(instance, attrgetter_type.handle);
}

def:priv attrgetter_clear(instance: u64) -> i32 {
    return clear_payload(instance, attrgetter_type.handle);
}

def:priv attrgetter_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, attrgetter_type.handle, visitor, context);
}

def:priv attrgetter_deallocate(instance: u64) {
    dispose_payload(instance, attrgetter_type.handle);
}

glob:priv attrgetter_type = TypeDefinition(
         "operator.attrgetter",
         "attrgetter(attr, /, *attrs)\n--\n\nFetch attributes from an operand.",
         [
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=attrgetter_reduce),
                 "Return state for pickling.",
                 flags=4
             )
         ],
         u64(
             TypeFlags.GC.value | TypeFlags.IMMUTABLE.value | TypeFlags.VECTORCALL.value
         ),
         TypeHooks(
             create=attrgetter_create,
             vectorcall=attrgetter_vector,
             repr=attrgetter_repr,
             clear=attrgetter_clear,
             traverse=attrgetter_traverse,
             dealloc=attrgetter_deallocate
         ),
         [PropertyDefinition("__text_signature__", accessor_signature)]
     );

def:priv methodcaller_create(type: u64, args: u64, kwargs: u64) -> u64 {
    return accessor_create(type, args, kwargs, methodcaller_type.handle, i64(2));
}

def:priv methodcaller_vector(instance: u64, args: u64, count: u64, names: u64) -> u64 {
    return accessor_vector(instance, args, count, names, methodcaller_type.handle);
}

def:priv methodcaller_repr(instance: u64) -> u64 {
    return accessor_repr(instance, methodcaller_type.handle);
}

def:priv methodcaller_reduce(instance: u64, unused: u64) -> u64 {
    return accessor_reduce(instance, methodcaller_type.handle);
}

def:priv methodcaller_clear(instance: u64) -> i32 {
    return clear_payload(instance, methodcaller_type.handle);
}

def:priv methodcaller_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, methodcaller_type.handle, visitor, context);
}

def:priv methodcaller_deallocate(instance: u64) {
    dispose_payload(instance, methodcaller_type.handle);
}

glob:priv methodcaller_type = TypeDefinition(
         "operator.methodcaller",
         "methodcaller(name, /, *args, **kwargs)\n--\n\nCall a method on an operand.",
         [
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=methodcaller_reduce),
                 "Return state for pickling.",
                 flags=4
             )
         ],
         u64(
             TypeFlags.GC.value | TypeFlags.IMMUTABLE.value | TypeFlags.VECTORCALL.value
         ),
         TypeHooks(
             create=methodcaller_create,
             vectorcall=methodcaller_vector,
             repr=methodcaller_repr,
             clear=methodcaller_clear,
             traverse=methodcaller_traverse,
             dealloc=methodcaller_deallocate
         ),
         [PropertyDefinition("__text_signature__", accessor_signature)]
     );

def:priv execute(module: u64) -> i32 {
    if not add_owned(module, "itemgetter", itemgetter_type.create(module)) {
        return i32(-1);
    }
    if not add_owned(module, "attrgetter", attrgetter_type.create(module)) {
        return i32(-1);
    }
    if not add_owned(module, "methodcaller", methodcaller_type.create(module)) {
        return i32(-1);
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_operator",
         "Native Jac implementations of Python operators.",
         [
             MethodDefinition(
                 "neg",
                 MethodCallbacks(positional=neg_call),
                 "neg($module, a, /)\n--\n\nApply the Python operator.",
                 flags=8
             ),
             MethodDefinition(
                 "pos",
                 MethodCallbacks(positional=pos_call),
                 "pos($module, a, /)\n--\n\nApply the Python operator.",
                 flags=8
             ),
             MethodDefinition(
                 "abs",
                 MethodCallbacks(positional=abs_call),
                 "abs($module, a, /)\n--\n\nApply the Python operator.",
                 flags=8
             ),
             MethodDefinition(
                 "invert",
                 MethodCallbacks(positional=invert_call),
                 "invert($module, a, /)\n--\n\nApply the Python operator.",
                 flags=8
             ),
             MethodDefinition(
                 "index",
                 MethodCallbacks(positional=index_call),
                 "index($module, a, /)\n--\n\nApply the Python operator.",
                 flags=8
             ),
             MethodDefinition(
                 "truth",
                 MethodCallbacks(positional=truth_call),
                 "truth($module, a, /)\n--\n\nApply the Python operator.",
                 flags=8
             ),
             MethodDefinition(
                 "not_",
                 MethodCallbacks(positional=not__call),
                 "not_($module, a, /)\n--\n\nApply the Python operator.",
                 flags=8
             ),
             MethodDefinition(
                 "is_none",
                 MethodCallbacks(positional=is_none_call),
                 "is_none($module, a, /)\n--\n\nApply the Python operator.",
                 flags=8
             ),
             MethodDefinition(
                 "is_not_none",
                 MethodCallbacks(positional=is_not_none_call),
                 "is_not_none($module, a, /)\n--\n\nApply the Python operator.",
                 flags=8
             ),
             MethodDefinition(
                 "inv",
                 MethodCallbacks(positional=invert_call),
                 "inv($module, a, /)\n--\n\nSame as ~a.",
                 flags=8
             ),
             MethodDefinition(
                 "add",
                 MethodCallbacks(positional=add_call),
                 "add($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "sub",
                 MethodCallbacks(positional=sub_call),
                 "sub($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "mul",
                 MethodCallbacks(positional=mul_call),
                 "mul($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "matmul",
                 MethodCallbacks(positional=matmul_call),
                 "matmul($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "floordiv",
                 MethodCallbacks(positional=floordiv_call),
                 "floordiv($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "truediv",
                 MethodCallbacks(positional=truediv_call),
                 "truediv($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "mod",
                 MethodCallbacks(positional=mod_call),
                 "mod($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "lshift",
                 MethodCallbacks(positional=lshift_call),
                 "lshift($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "rshift",
                 MethodCallbacks(positional=rshift_call),
                 "rshift($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "and_",
                 MethodCallbacks(positional=and__call),
                 "and_($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "xor",
                 MethodCallbacks(positional=xor_call),
                 "xor($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "or_",
                 MethodCallbacks(positional=or__call),
                 "or_($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "iadd",
                 MethodCallbacks(positional=iadd_call),
                 "iadd($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "isub",
                 MethodCallbacks(positional=isub_call),
                 "isub($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "imul",
                 MethodCallbacks(positional=imul_call),
                 "imul($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "imatmul",
                 MethodCallbacks(positional=imatmul_call),
                 "imatmul($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "ifloordiv",
                 MethodCallbacks(positional=ifloordiv_call),
                 "ifloordiv($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "itruediv",
                 MethodCallbacks(positional=itruediv_call),
                 "itruediv($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "imod",
                 MethodCallbacks(positional=imod_call),
                 "imod($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "ilshift",
                 MethodCallbacks(positional=ilshift_call),
                 "ilshift($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "irshift",
                 MethodCallbacks(positional=irshift_call),
                 "irshift($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "iand",
                 MethodCallbacks(positional=iand_call),
                 "iand($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "ixor",
                 MethodCallbacks(positional=ixor_call),
                 "ixor($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "ior",
                 MethodCallbacks(positional=ior_call),
                 "ior($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "concat",
                 MethodCallbacks(positional=concat_call),
                 "concat($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "iconcat",
                 MethodCallbacks(positional=iconcat_call),
                 "iconcat($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "getitem",
                 MethodCallbacks(positional=getitem_call),
                 "getitem($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "is_",
                 MethodCallbacks(positional=is__call),
                 "is_($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "is_not",
                 MethodCallbacks(positional=is_not_call),
                 "is_not($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "pow",
                 MethodCallbacks(positional=pow_call),
                 "pow($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "ipow",
                 MethodCallbacks(positional=ipow_call),
                 "ipow($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "contains",
                 MethodCallbacks(positional=contains_call),
                 "contains($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "indexOf",
                 MethodCallbacks(positional=indexOf_call),
                 "indexOf($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "countOf",
                 MethodCallbacks(positional=countOf_call),
                 "countOf($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "delitem",
                 MethodCallbacks(positional=delitem_call),
                 "delitem($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "lt",
                 MethodCallbacks(positional=lt_call),
                 "lt($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "le",
                 MethodCallbacks(positional=le_call),
                 "le($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "eq",
                 MethodCallbacks(positional=eq_call),
                 "eq($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "ne",
                 MethodCallbacks(positional=ne_call),
                 "ne($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "gt",
                 MethodCallbacks(positional=gt_call),
                 "gt($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "ge",
                 MethodCallbacks(positional=ge_call),
                 "ge($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=1
             ),
             MethodDefinition(
                 "setitem",
                 MethodCallbacks(positional=setitem_call),
                 "setitem($module, a, b, c, /)\n--\n\nSame as a[b] = c.",
                 flags=1
             ),
             MethodDefinition(
                 "length_hint",
                 MethodCallbacks(positional=length_hint_call),
                 "length_hint($module, obj, default=0, /)\n--\n\nEstimate an iterable's length.",
                 flags=1
             ),
             MethodDefinition(
                 "call",
                 MethodCallbacks(keywords=call_call),
                 "call($module, obj, /, *args, **kwargs)\n--\n\nCall obj."
             ),
             MethodDefinition(
                 "_compare_digest",
                 MethodCallbacks(positional=digest_call),
                 "_compare_digest($module, a, b, /)\n--\n\nCompare without content-dependent timing.",
                 flags=1
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__operator -> u64 {
    return definition.initialize();
}

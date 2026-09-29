"""Python operator bindings and native accessor state."""

import from jaclang.runtime.python.cpython_api {
    NULL,
    PyExc_BufferError,
    PyExc_SystemError,
    PyExc_TypeError,
    PyObject,
    PyObject_CheckBuffer,
    PyTuple_Size,
    PyVectorcall_NARGS,
    Py_NewRef,
    Py_TYPE,
    jacpy_dict_size,
    jacpy_is_unicode,
    jacpy_release,
    jacpy_unicode_ascii
}
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
    PropertyCallbacks,
    PropertyDefinition,
    jacpy_binding_allocate
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
    index_value,
    invoke_vector
}
import from jaclang.runtime.python.bindings.buffer { BufferArgument }
import from jaclang.runtime.python.capi {
    object_error,
    type_name,
    text_object,
    boundary_failure
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

def:priv neg_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return invoke_one(value, jacpy_operator_neg);
}

def:priv pos_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return invoke_one(value, jacpy_operator_pos);
}

def:priv abs_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return invoke_one(value, jacpy_operator_abs);
}

def:priv invert_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return invoke_one(value, jacpy_operator_invert);
}

def:priv index_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return invoke_one(value, jacpy_operator_index);
}

def:priv truth_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return invoke_one(value, jacpy_operator_truth);
}

def:priv not__call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return invoke_one(value, jacpy_operator_not_);
}

def:priv is_none_call(module: ptr[PyObject], value: ptr[PyObject]) -> ptr[PyObject] {
    return invoke_one(value, jacpy_operator_is_none);
}

def:priv is_not_none_call(
    module: ptr[PyObject], value: ptr[PyObject]
) -> ptr[PyObject] {
    return invoke_one(value, jacpy_operator_is_not_none);
}

glob:priv add_signature = CallSignature("add", ["a", "b"], 2, 2, 2);
def:priv add_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_add(args.values[0], args.values[1]);
}

def:priv add_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(add_signature, args, nargs, NULL, add_bound);
}

glob:priv sub_signature = CallSignature("sub", ["a", "b"], 2, 2, 2);
def:priv sub_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_sub(args.values[0], args.values[1]);
}

def:priv sub_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(sub_signature, args, nargs, NULL, sub_bound);
}

glob:priv mul_signature = CallSignature("mul", ["a", "b"], 2, 2, 2);
def:priv mul_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_mul(args.values[0], args.values[1]);
}

def:priv mul_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(mul_signature, args, nargs, NULL, mul_bound);
}

glob:priv matmul_signature = CallSignature("matmul", ["a", "b"], 2, 2, 2);
def:priv matmul_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_matmul(args.values[0], args.values[1]);
}

def:priv matmul_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(matmul_signature, args, nargs, NULL, matmul_bound);
}

glob:priv floordiv_signature = CallSignature("floordiv", ["a", "b"], 2, 2, 2);
def:priv floordiv_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_floordiv(args.values[0], args.values[1]);
}

def:priv floordiv_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(floordiv_signature, args, nargs, NULL, floordiv_bound);
}

glob:priv truediv_signature = CallSignature("truediv", ["a", "b"], 2, 2, 2);
def:priv truediv_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_truediv(args.values[0], args.values[1]);
}

def:priv truediv_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(truediv_signature, args, nargs, NULL, truediv_bound);
}

glob:priv mod_signature = CallSignature("mod", ["a", "b"], 2, 2, 2);
def:priv mod_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_mod(args.values[0], args.values[1]);
}

def:priv mod_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(mod_signature, args, nargs, NULL, mod_bound);
}

glob:priv lshift_signature = CallSignature("lshift", ["a", "b"], 2, 2, 2);
def:priv lshift_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_lshift(args.values[0], args.values[1]);
}

def:priv lshift_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(lshift_signature, args, nargs, NULL, lshift_bound);
}

glob:priv rshift_signature = CallSignature("rshift", ["a", "b"], 2, 2, 2);
def:priv rshift_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_rshift(args.values[0], args.values[1]);
}

def:priv rshift_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(rshift_signature, args, nargs, NULL, rshift_bound);
}

glob:priv and__signature = CallSignature("and_", ["a", "b"], 2, 2, 2);
def:priv and__bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_and_(args.values[0], args.values[1]);
}

def:priv and__call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(and__signature, args, nargs, NULL, and__bound);
}

glob:priv xor_signature = CallSignature("xor", ["a", "b"], 2, 2, 2);
def:priv xor_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_xor(args.values[0], args.values[1]);
}

def:priv xor_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(xor_signature, args, nargs, NULL, xor_bound);
}

glob:priv or__signature = CallSignature("or_", ["a", "b"], 2, 2, 2);
def:priv or__bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_or_(args.values[0], args.values[1]);
}

def:priv or__call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(or__signature, args, nargs, NULL, or__bound);
}

glob:priv iadd_signature = CallSignature("iadd", ["a", "b"], 2, 2, 2);
def:priv iadd_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_iadd(args.values[0], args.values[1]);
}

def:priv iadd_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(iadd_signature, args, nargs, NULL, iadd_bound);
}

glob:priv isub_signature = CallSignature("isub", ["a", "b"], 2, 2, 2);
def:priv isub_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_isub(args.values[0], args.values[1]);
}

def:priv isub_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(isub_signature, args, nargs, NULL, isub_bound);
}

glob:priv imul_signature = CallSignature("imul", ["a", "b"], 2, 2, 2);
def:priv imul_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_imul(args.values[0], args.values[1]);
}

def:priv imul_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(imul_signature, args, nargs, NULL, imul_bound);
}

glob:priv imatmul_signature = CallSignature("imatmul", ["a", "b"], 2, 2, 2);
def:priv imatmul_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_imatmul(args.values[0], args.values[1]);
}

def:priv imatmul_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(imatmul_signature, args, nargs, NULL, imatmul_bound);
}

glob:priv ifloordiv_signature = CallSignature("ifloordiv", ["a", "b"], 2, 2, 2);
def:priv ifloordiv_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_ifloordiv(args.values[0], args.values[1]);
}

def:priv ifloordiv_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(ifloordiv_signature, args, nargs, NULL, ifloordiv_bound);
}

glob:priv itruediv_signature = CallSignature("itruediv", ["a", "b"], 2, 2, 2);
def:priv itruediv_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_itruediv(args.values[0], args.values[1]);
}

def:priv itruediv_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(itruediv_signature, args, nargs, NULL, itruediv_bound);
}

glob:priv imod_signature = CallSignature("imod", ["a", "b"], 2, 2, 2);
def:priv imod_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_imod(args.values[0], args.values[1]);
}

def:priv imod_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(imod_signature, args, nargs, NULL, imod_bound);
}

glob:priv ilshift_signature = CallSignature("ilshift", ["a", "b"], 2, 2, 2);
def:priv ilshift_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_ilshift(args.values[0], args.values[1]);
}

def:priv ilshift_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(ilshift_signature, args, nargs, NULL, ilshift_bound);
}

glob:priv irshift_signature = CallSignature("irshift", ["a", "b"], 2, 2, 2);
def:priv irshift_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_irshift(args.values[0], args.values[1]);
}

def:priv irshift_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(irshift_signature, args, nargs, NULL, irshift_bound);
}

glob:priv iand_signature = CallSignature("iand", ["a", "b"], 2, 2, 2);
def:priv iand_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_iand(args.values[0], args.values[1]);
}

def:priv iand_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(iand_signature, args, nargs, NULL, iand_bound);
}

glob:priv ixor_signature = CallSignature("ixor", ["a", "b"], 2, 2, 2);
def:priv ixor_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_ixor(args.values[0], args.values[1]);
}

def:priv ixor_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(ixor_signature, args, nargs, NULL, ixor_bound);
}

glob:priv ior_signature = CallSignature("ior", ["a", "b"], 2, 2, 2);
def:priv ior_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_ior(args.values[0], args.values[1]);
}

def:priv ior_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(ior_signature, args, nargs, NULL, ior_bound);
}

glob:priv concat_signature = CallSignature("concat", ["a", "b"], 2, 2, 2);
def:priv concat_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_concat(args.values[0], args.values[1]);
}

def:priv concat_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(concat_signature, args, nargs, NULL, concat_bound);
}

glob:priv iconcat_signature = CallSignature("iconcat", ["a", "b"], 2, 2, 2);
def:priv iconcat_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_iconcat(args.values[0], args.values[1]);
}

def:priv iconcat_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(iconcat_signature, args, nargs, NULL, iconcat_bound);
}

glob:priv getitem_signature = CallSignature("getitem", ["a", "b"], 2, 2, 2);
def:priv getitem_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_getitem(args.values[0], args.values[1]);
}

def:priv getitem_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(getitem_signature, args, nargs, NULL, getitem_bound);
}

glob:priv is__signature = CallSignature("is_", ["a", "b"], 2, 2, 2);
def:priv is__bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_is_(args.values[0], args.values[1]);
}

def:priv is__call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(is__signature, args, nargs, NULL, is__bound);
}

glob:priv is_not_signature = CallSignature("is_not", ["a", "b"], 2, 2, 2);
def:priv is_not_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_is_not(args.values[0], args.values[1]);
}

def:priv is_not_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(is_not_signature, args, nargs, NULL, is_not_bound);
}

glob:priv pow_signature = CallSignature("pow", ["a", "b"], 2, 2, 2);
def:priv pow_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_pow(args.values[0], args.values[1]);
}

def:priv pow_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(pow_signature, args, nargs, NULL, pow_bound);
}

glob:priv ipow_signature = CallSignature("ipow", ["a", "b"], 2, 2, 2);
def:priv ipow_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_ipow(args.values[0], args.values[1]);
}

def:priv ipow_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(ipow_signature, args, nargs, NULL, ipow_bound);
}

glob:priv contains_signature = CallSignature("contains", ["a", "b"], 2, 2, 2);
def:priv contains_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_contains(args.values[0], args.values[1]);
}

def:priv contains_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(contains_signature, args, nargs, NULL, contains_bound);
}

glob:priv indexOf_signature = CallSignature("indexOf", ["a", "b"], 2, 2, 2);
def:priv indexOf_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_indexOf(args.values[0], args.values[1]);
}

def:priv indexOf_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(indexOf_signature, args, nargs, NULL, indexOf_bound);
}

glob:priv countOf_signature = CallSignature("countOf", ["a", "b"], 2, 2, 2);
def:priv countOf_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_countOf(args.values[0], args.values[1]);
}

def:priv countOf_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(countOf_signature, args, nargs, NULL, countOf_bound);
}

glob:priv delitem_signature = CallSignature("delitem", ["a", "b"], 2, 2, 2);
def:priv delitem_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_delitem(args.values[0], args.values[1]);
}

def:priv delitem_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(delitem_signature, args, nargs, NULL, delitem_bound);
}

glob:priv lt_signature = CallSignature("lt", ["a", "b"], 2, 2, 2);
def:priv lt_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(0));
}

def:priv lt_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(lt_signature, args, nargs, NULL, lt_bound);
}

glob:priv le_signature = CallSignature("le", ["a", "b"], 2, 2, 2);
def:priv le_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(1));
}

def:priv le_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(le_signature, args, nargs, NULL, le_bound);
}

glob:priv eq_signature = CallSignature("eq", ["a", "b"], 2, 2, 2);
def:priv eq_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(2));
}

def:priv eq_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(eq_signature, args, nargs, NULL, eq_bound);
}

glob:priv ne_signature = CallSignature("ne", ["a", "b"], 2, 2, 2);
def:priv ne_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(3));
}

def:priv ne_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(ne_signature, args, nargs, NULL, ne_bound);
}

glob:priv gt_signature = CallSignature("gt", ["a", "b"], 2, 2, 2);
def:priv gt_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(4));
}

def:priv gt_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(gt_signature, args, nargs, NULL, gt_bound);
}

glob:priv ge_signature = CallSignature("ge", ["a", "b"], 2, 2, 2);
def:priv ge_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_compare(args.values[0], args.values[1], i64(5));
}

def:priv ge_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(ge_signature, args, nargs, NULL, ge_bound);
}

glob:priv setitem_signature = CallSignature("setitem", ["a", "b", "c"], 3, 3, 3),
     length_hint_signature = CallSignature("length_hint", ["obj", "default"], 1, 2, 2),
     digest_signature = CallSignature("_compare_digest", ["a", "b"], 2, 2, 2);

def:priv setitem_bound(args: BoundArguments) -> ptr[PyObject] {
    return jacpy_operator_setitem(args.values[0], args.values[1], args.values[2]);
}

def:priv setitem_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(setitem_signature, args, nargs, NULL, setitem_bound);
}

def:priv length_hint_bound(args: BoundArguments) -> ptr[PyObject] {
    fallback: i64 = 0;
    if args.values[1] != 0 {
        value = index_value(args.values[1]);
        if value is None {
            return NULL;
        }
        fallback = value;
    }
    return jacpy_operator_length_hint(args.values[0], fallback);
}

def:priv length_hint_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(length_hint_signature, args, nargs, NULL, length_hint_bound);
}

def:priv call_call(
    module: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    if PyTuple_Size(args) == 0 {
        object_error(PyExc_TypeError, "call expected at least 1 argument, got 0");
        return NULL;
    }
    return jacpy_operator_call(args, kwargs);
}

def:priv digest_bound(args: BoundArguments) -> ptr[PyObject] {
    a = args.values[0];
    b = args.values[1];
    ascii = jacpy_is_unicode(a) != 0 and jacpy_is_unicode(b) != 0;
    if ascii {
        if jacpy_unicode_ascii(a) == 0 or jacpy_unicode_ascii(b) == 0 {
            object_error(
                PyExc_TypeError,
                "comparing strings with non-ASCII characters is not supported"
            );
            return NULL;
        }
    } elif PyObject_CheckBuffer(a) == 0 and PyObject_CheckBuffer(b) == 0 {
        object_error(
            PyExc_TypeError,
            f"unsupported operand types(s) or combination of types: '{type_name(a)[:100]}' and '{type_name(
                b
            )[:100]}'"
        );
        return NULL;
    }
    av = BufferArgument();
    bv = BufferArgument();
    if not av.acquire(a, ascii) {
        return NULL;
    }
    if av.dimensions() > 1 {
        object_error(PyExc_BufferError, "Buffer must be single dimension");
        return NULL;
    }
    if not bv.acquire(b, ascii) {
        return NULL;
    }
    if bv.dimensions() > 1 {
        object_error(PyExc_BufferError, "Buffer must be single dimension");
        return NULL;
    }
    return jacpy_operator_digest(av.address(), bv.address(), av.size(), bv.size());
}

def:priv digest_call(
    module: ptr[PyObject], args: ptr[ptr[PyObject]], nargs: i64
) -> ptr[PyObject] {
    return invoke_vector(digest_signature, args, nargs, NULL, digest_bound);
}

obj AccessorState(ReferenceState) {
    has kind: i64;
}

def:priv accessor_state(
    instance: ptr[PyObject], definition: ptr
) -> (AccessorState | None) {
    if jacpy_binding_native_present(instance, definition) != 0 {
        state = jacpy_binding_native_get(instance, definition);
        if isinstance(state, AccessorState) {
            return state;
        }
    }
    object_error(PyExc_SystemError, "native accessor state is unavailable");
    return None;
}

def:priv accessor_create(
    type: ptr[PyObject],
    args: ptr[PyObject],
    kwargs: ptr[PyObject],
    definition: ptr,
    kind: i64
) -> ptr[PyObject] {
    if kind != 2 and jacpy_dict_size(kwargs) != 0 {
        object_error(
            PyExc_TypeError, f"{type_name(type, True)}() takes no keyword arguments"
        );
        return NULL;
    }
    if PyTuple_Size(args) < 1 {
        object_error(
            PyExc_TypeError,
            f"{type_name(type, True)} expected at least 1 argument, got 0"
        );
        return NULL;
    }
    prepared = jacpy_operator_prepare(kind, args);
    if prepared == 0 {
        return NULL;
    }
    state = AccessorState(
        references=[prepared, Py_NewRef(kwargs) if kwargs != 0 else NULL], kind=kind
    );
    instance = jacpy_binding_allocate(type);
    if instance == 0 {
        return NULL;
    }
    if jacpy_binding_native_set(instance, definition, state) < 0 {
        jacpy_release(instance);
        return NULL;
    }
    return instance;
}

def:priv accessor_vector(
    instance: ptr[PyObject],
    args: ptr,
    count: u64,
    names: ptr[PyObject],
    definition: ptr
) -> ptr[PyObject] {
    if names != 0 and PyTuple_Size(names) != 0 {
        object_error(
            PyExc_TypeError, f"{type_name(instance)}() takes no keyword arguments"
        );
        return NULL;
    }
    size = PyVectorcall_NARGS(count);
    if size != 1 {
        object_error(
            PyExc_TypeError, f"{type_name(instance)} expected 1 argument, got {size}"
        );
        return NULL;
    }
    state = accessor_state(instance, definition);
    if state is None {
        return NULL;
    }
    return jacpy_operator_apply(
        state.kind,
        ptr[ptr[PyObject]](int(args)).view(1)[0],
        state.references[0],
        state.references[1]
    );
}

def:priv accessor_repr(instance: ptr[PyObject], definition: ptr) -> ptr[PyObject] {
    state = accessor_state(instance, definition);
    if state is None {
        return NULL;
    }
    return jacpy_operator_repr(
        state.kind, instance, state.references[0], state.references[1]
    );
}

def:priv accessor_reduce(instance: ptr[PyObject], definition: ptr) -> ptr[PyObject] {
    state = accessor_state(instance, definition);
    if state is None {
        return NULL;
    }
    return jacpy_operator_reduce(
        state.kind, Py_TYPE(instance), state.references[0], state.references[1]
    );
}

def:priv accessor_signature(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    try {
        return text_object("(obj, /)");
    } except boundary_failure {
        return NULL;
    }
}

def:priv itemgetter_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_create(type, args, kwargs, itemgetter_type.handle, i64(0));
}

def:priv itemgetter_vector(
    instance: ptr[PyObject], args: ptr, count: u64, names: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_vector(instance, args, count, names, itemgetter_type.handle);
}

def:priv itemgetter_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    return accessor_repr(instance, itemgetter_type.handle);
}

def:priv itemgetter_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_reduce(instance, itemgetter_type.handle);
}

def:priv itemgetter_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, itemgetter_type.handle);
}

def:priv itemgetter_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, itemgetter_type.handle, visitor, context);
}

def:priv itemgetter_deallocate(instance: ptr[PyObject]) {
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
         [
             PropertyDefinition(
                 "__text_signature__", PropertyCallbacks(read=accessor_signature)
             )
         ]
     );

def:priv attrgetter_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_create(type, args, kwargs, attrgetter_type.handle, i64(1));
}

def:priv attrgetter_vector(
    instance: ptr[PyObject], args: ptr, count: u64, names: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_vector(instance, args, count, names, attrgetter_type.handle);
}

def:priv attrgetter_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    return accessor_repr(instance, attrgetter_type.handle);
}

def:priv attrgetter_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_reduce(instance, attrgetter_type.handle);
}

def:priv attrgetter_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, attrgetter_type.handle);
}

def:priv attrgetter_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, attrgetter_type.handle, visitor, context);
}

def:priv attrgetter_deallocate(instance: ptr[PyObject]) {
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
         [
             PropertyDefinition(
                 "__text_signature__", PropertyCallbacks(read=accessor_signature)
             )
         ]
     );

def:priv methodcaller_create(
    type: ptr[PyObject], args: ptr[PyObject], kwargs: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_create(type, args, kwargs, methodcaller_type.handle, i64(2));
}

def:priv methodcaller_vector(
    instance: ptr[PyObject], args: ptr, count: u64, names: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_vector(instance, args, count, names, methodcaller_type.handle);
}

def:priv methodcaller_repr(instance: ptr[PyObject]) -> ptr[PyObject] {
    return accessor_repr(instance, methodcaller_type.handle);
}

def:priv methodcaller_reduce(
    instance: ptr[PyObject], unused: ptr[PyObject]
) -> ptr[PyObject] {
    return accessor_reduce(instance, methodcaller_type.handle);
}

def:priv methodcaller_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, methodcaller_type.handle);
}

def:priv methodcaller_traverse(
    instance: ptr[PyObject], visitor: ptr[PyObject], context: ptr[PyObject]
) -> i32 {
    return traverse_payload(instance, methodcaller_type.handle, visitor, context);
}

def:priv methodcaller_deallocate(instance: ptr[PyObject]) {
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
         [
             PropertyDefinition(
                 "__text_signature__", PropertyCallbacks(read=accessor_signature)
             )
         ]
     );

def:priv execute(module: ptr[PyObject]) -> i32 {
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
                 MethodCallbacks(fast=add_call),
                 "add($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "sub",
                 MethodCallbacks(fast=sub_call),
                 "sub($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "mul",
                 MethodCallbacks(fast=mul_call),
                 "mul($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "matmul",
                 MethodCallbacks(fast=matmul_call),
                 "matmul($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "floordiv",
                 MethodCallbacks(fast=floordiv_call),
                 "floordiv($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "truediv",
                 MethodCallbacks(fast=truediv_call),
                 "truediv($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "mod",
                 MethodCallbacks(fast=mod_call),
                 "mod($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "lshift",
                 MethodCallbacks(fast=lshift_call),
                 "lshift($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "rshift",
                 MethodCallbacks(fast=rshift_call),
                 "rshift($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "and_",
                 MethodCallbacks(fast=and__call),
                 "and_($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "xor",
                 MethodCallbacks(fast=xor_call),
                 "xor($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "or_",
                 MethodCallbacks(fast=or__call),
                 "or_($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "iadd",
                 MethodCallbacks(fast=iadd_call),
                 "iadd($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "isub",
                 MethodCallbacks(fast=isub_call),
                 "isub($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "imul",
                 MethodCallbacks(fast=imul_call),
                 "imul($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "imatmul",
                 MethodCallbacks(fast=imatmul_call),
                 "imatmul($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "ifloordiv",
                 MethodCallbacks(fast=ifloordiv_call),
                 "ifloordiv($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "itruediv",
                 MethodCallbacks(fast=itruediv_call),
                 "itruediv($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "imod",
                 MethodCallbacks(fast=imod_call),
                 "imod($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "ilshift",
                 MethodCallbacks(fast=ilshift_call),
                 "ilshift($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "irshift",
                 MethodCallbacks(fast=irshift_call),
                 "irshift($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "iand",
                 MethodCallbacks(fast=iand_call),
                 "iand($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "ixor",
                 MethodCallbacks(fast=ixor_call),
                 "ixor($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "ior",
                 MethodCallbacks(fast=ior_call),
                 "ior($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "concat",
                 MethodCallbacks(fast=concat_call),
                 "concat($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "iconcat",
                 MethodCallbacks(fast=iconcat_call),
                 "iconcat($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "getitem",
                 MethodCallbacks(fast=getitem_call),
                 "getitem($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "is_",
                 MethodCallbacks(fast=is__call),
                 "is_($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "is_not",
                 MethodCallbacks(fast=is_not_call),
                 "is_not($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "pow",
                 MethodCallbacks(fast=pow_call),
                 "pow($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "ipow",
                 MethodCallbacks(fast=ipow_call),
                 "ipow($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "contains",
                 MethodCallbacks(fast=contains_call),
                 "contains($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "indexOf",
                 MethodCallbacks(fast=indexOf_call),
                 "indexOf($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "countOf",
                 MethodCallbacks(fast=countOf_call),
                 "countOf($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "delitem",
                 MethodCallbacks(fast=delitem_call),
                 "delitem($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "lt",
                 MethodCallbacks(fast=lt_call),
                 "lt($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "le",
                 MethodCallbacks(fast=le_call),
                 "le($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "eq",
                 MethodCallbacks(fast=eq_call),
                 "eq($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "ne",
                 MethodCallbacks(fast=ne_call),
                 "ne($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "gt",
                 MethodCallbacks(fast=gt_call),
                 "gt($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "ge",
                 MethodCallbacks(fast=ge_call),
                 "ge($module, a, b, /)\n--\n\nApply the Python operator.",
                 flags=128
             ),
             MethodDefinition(
                 "setitem",
                 MethodCallbacks(fast=setitem_call),
                 "setitem($module, a, b, c, /)\n--\n\nSame as a[b] = c.",
                 flags=128
             ),
             MethodDefinition(
                 "length_hint",
                 MethodCallbacks(fast=length_hint_call),
                 "length_hint($module, obj, default=0, /)\n--\n\nEstimate an iterable's length.",
                 flags=128
             ),
             MethodDefinition(
                 "call",
                 MethodCallbacks(keywords=call_call),
                 "call($module, obj, /, *args, **kwargs)\n--\n\nCall obj."
             ),
             MethodDefinition(
                 "_compare_digest",
                 MethodCallbacks(fast=digest_call),
                 "_compare_digest($module, a, b, /)\n--\n\nCompare without content-dependent timing.",
                 flags=128
             )
         ],
         ModuleHooks(execute=execute)
     );

def:pub PyInit__operator -> ptr[PyObject] {
    return definition.initialize();
}

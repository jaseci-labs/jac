"""The runtime functions generated code calls, by symbol, with their MIR
signatures: the return spec first, then the parameters. The runtime units in
jaclang/runtime/native define them in Jac. A `str.ref` result is an owned
string the caller releases."""
glob MIR_RUNTIME_ABI: dict[str, list[str]] = {
         "__jac_rt_str_cmp": ["int", "ptr", "int", "ptr", "int"],
         "__jac_rt_str_len": ["int", "ptr", "ptr", "int"],
         "__jac_rt_str_new": ["str.ref", "ptr", "int"],
         "__jac_rt_str_concat": ["str.ref", "ptr", "int", "ptr", "int"],
         "__jac_rt_str_from_int": ["str.ref", "int"],
         "__jac_rt_str_size": ["int", "str.ref"],
         "__jac_rt_str_ref": ["str.ref", "ptr", "ptr", "int"],
         "__jac_rt_list_new": ["ref", "int", "int"],
         "__jac_rt_list_push": ["none", "ref", "int", "int"],
         "__jac_rt_list_set": ["none", "ref", "int", "int", "int"],
         "__jac_rt_list_get_ref": ["ref", "ref", "int", "int"],
         "__jac_rt_list_pop": ["int", "ref", "int"],
         "__jac_rt_list_insert": ["none", "ref", "int", "int", "int"],
         "__jac_rt_list_clear": ["none", "ref", "int"],
         "__jac_rt_list_copy": ["ref", "ref", "int"],
         "__jac_rt_list_extend": ["none", "ref", "ref", "int"],
         "__jac_rt_list_reverse": ["none", "ref"],
         "__jac_rt_list_index": ["int", "ref", "int", "int"],
         "__jac_rt_list_contains": ["bool", "ref", "int", "int"],
         "__jac_rt_list_eq": ["bool", "ref", "ref", "int"],
         "__jac_rt_list_slice": ["ref", "ref", "int", "int", "int", "int"],
         "__jac_rt_list_sort": ["none", "ref", "int", "bool"],
         "__jac_rt_dict_new": ["ref", "int", "int"],
         "__jac_rt_dict_len": ["int", "ref"],
         "__jac_rt_dict_find": ["int", "ref", "int", "int"],
         "__jac_rt_dict_set": ["none", "ref", "int", "int", "int", "int"],
         "__jac_rt_dict_del": ["bool", "ref", "int", "int", "int"],
         "__jac_rt_dict_key_at": ["int", "ref", "int"],
         "__jac_rt_dict_val_at": ["int", "ref", "int"],
         "__jac_rt_dict_key_ref": ["ref", "ref", "int", "int"],
         "__jac_rt_dict_val_ref": ["ref", "ref", "int", "int"],
         "__jac_rt_dict_next": ["int", "ref", "int"],
         "__jac_rt_dict_pop": ["int", "ref", "int", "int", "int", "int"],
         "__jac_rt_dict_clear": ["none", "ref", "int", "int"],
         "__jac_rt_dict_copy": ["ref", "ref", "int", "int"],
         "__jac_rt_dict_update": ["none", "ref", "ref", "int", "int"],
         "__jac_rt_dict_eq": ["bool", "ref", "ref", "int", "int"],
         "__jac_rt_alloc": ["ref", "int"],
         "__jac_rt_set_type": ["none", "ref", "ptr"],
         "__jac_rt_free_block": ["none", "int"],
         "__jac_rt_release": ["none", "ref"],
         "__jac_rt_trace_register": ["none", "int", "int"],
         "__jac_rt_exc_push": ["none", "ptr"],
         "__jac_rt_exc_pop": ["none", "ptr"],
         "__jac_rt_exc_jmp_buf": ["ptr", "ptr"],
         "__jac_rt_raise": ["none", "ptr", "i32", "ptr"],
         "__jac_rt_write": ["none", "int", "ptr", "int"],
         "__jac_rt_write_int": ["none", "int", "int"]
     };

def mir_runtime_signature(name: str) -> tuple[list[MirType], MirType];

def mir_runtime_spec(spec: str) -> MirType;

"""The methods of builtin types that native code lowers, by type name. The
checker and placement read this to know which method calls stay native."""
glob MIR_PRIMITIVE_METHODS: dict[str, list[str]] = {
         "list": [
             "append", "clear", "copy", "extend", "index", "insert", "pop", "reverse", "sort"
         ],
         "dict": ["clear", "copy", "get", "keys", "pop", "update", "values"],
         "set": ["add", "clear", "copy", "discard", "remove", "update"],
         "str": []
     };

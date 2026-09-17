"""CSV declarations, owned callbacks, and interpreter-local native configuration."""
import from jaclang.runtime.python.bindings.module {
    ModuleDefinition,
    MethodCallbacks,
    MethodDefinition,
    ModuleHooks,
    add_owned,
    add_state_owned,
    jacpy_binding_exception,
    jacpy_binding_state_get,
    jacpy_binding_visit,
    jacpy_binding_module_native_get,
    jacpy_binding_module_native_set,
    jacpy_binding_module_native_present
}
import from jaclang.runtime.python.bindings.type {
    TypeDefinition,
    TypeHooks,
    TypeFlags,
    PropertyCallbacks,
    PropertyDefinition,
    jacpy_binding_typeof,
    jacpy_binding_owner,
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
    jacpy_ssize
}
import from jaclang.runtime.python.modules.csv {
    CsvConfig,
    csv_reader,
    csv_writer,
    jacpy_csv_dialect,
    jacpy_csv_read,
    jacpy_csv_reader_clear,
    jacpy_csv_reader_fields,
    jacpy_csv_reader_line,
    jacpy_csv_write,
    jacpy_csv_registry
}
import from jaclang.runtime.python.capi {
    jacpy_release,
    jacpy_retain,
    jacpy_none,
    jacpy_int,
    jacpy_dict_new,
    jacpy_dict_set,
    jacpy_text,
    jacpy_tuple_new,
    jacpy_tuple_item,
    jacpy_tuple_set_owned,
    jacpy_call,
    jacpy_type_check,
    jacpy_integer_value,
    jacpy_unicode_from_ordinal,
    jacpy_is_unicode,
    jacpy_is_exact_long,
    jacpy_error_pending,
    jacpy_iter,
    jacpy_optional_attr,
    jacpy_callable,
    object_error,
    type_name
}

obj CsvReaderState(ReferenceState) {
    has native: csv_reader;

    def clear {
        super.clear();
        jacpy_csv_reader_clear(self.native);
    }

    def traverse_refs(visitor: u64, context: u64) -> i32 {
        status = super.traverse_refs(visitor, context);
        if status != 0 {
            return status;
        }
        return jacpy_binding_visit(
            jacpy_csv_reader_fields(self.native), visitor, context
        );
    }
}

obj CsvWriterState(ReferenceState) {
    has native: csv_writer;
}

def:priv module_for(instance: u64) -> u64 {
    return jacpy_binding_owner(jacpy_binding_typeof(instance), definition.handle);
}

def:priv config_for(module: u64) -> (CsvConfig | None) {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        if isinstance(state, CsvConfig) {
            return state;
        }
    }
    object_error("SystemError", "native CSV configuration is unavailable");
    return None;
}

def:priv dialect_options(instance: u64) -> u64 {
    if jacpy_binding_native_present(instance, dialect_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, dialect_type.handle);
        if isinstance(state, ReferenceState) {
            return state.references[0];
        }
    }
    return 0;
}

def:priv reader_state(instance: u64) -> (CsvReaderState | None) {
    if jacpy_binding_native_present(instance, reader_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, reader_type.handle);
        if isinstance(state, CsvReaderState) {
            return state;
        }
    }
    object_error("SystemError", "native CSV reader state is unavailable");
    return None;
}

def:priv writer_state(instance: u64) -> (CsvWriterState | None) {
    if jacpy_binding_native_present(instance, writer_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, writer_type.handle);
        if isinstance(state, CsvWriterState) {
            return state;
        }
    }
    object_error("SystemError", "native CSV writer state is unavailable");
    return None;
}

glob:priv option_names = [
         "delimiter",
         "doublequote",
         "escapechar",
         "lineterminator",
         "quotechar",
         "quoting",
         "skipinitialspace",
         "strict"
     ],
     dialect_signature = CallSignature("Dialect", ["dialect"] + option_names, 0, 9);

def:priv dialect_create_bound(args: BoundArguments) -> u64 {
    module = jacpy_binding_owner(args.context, definition.handle);
    if module == 0 {
        return 0;
    }
    overrides = jacpy_dict_new();
    if overrides == 0 {
        return 0;
    }
    for i in range(8) {
        if args.values[i + 1] != 0 {
            name = option_names[i];
            key = jacpy_text(name, i64(len(name)));
            if key == 0 {
                jacpy_release(overrides);
                return 0;
            }
            status = jacpy_dict_set(overrides, key, args.values[i + 1]);
            jacpy_release(key);
            if status < 0 {
                jacpy_release(overrides);
                return 0;
            }
        }
    }
    settings = jacpy_csv_dialect(
        args.values[0],
        overrides,
        jacpy_binding_state_get(module, 1),
        jacpy_binding_state_get(module, 2),
        jacpy_binding_state_get(module, 0)
    );
    jacpy_release(overrides);
    if settings == 0
        or jacpy_type_check(settings, jacpy_binding_state_get(module, 2)) != 0 {
        return settings;
    }
    state = ReferenceState(references=[settings]);
    instance = jacpy_binding_allocate(args.context);
    if instance == 0 {
        return 0;
    }
    if jacpy_binding_native_set(instance, dialect_type.handle, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv dialect_create(type: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(dialect_signature, args, kwargs, dialect_create_bound, type);
}

def:priv dialect_option(instance: u64, context: u64) -> u64 {
    settings = dialect_options(instance);
    if settings == 0 {
        return jacpy_none();
    }
    value = jacpy_tuple_item(settings, i64(context));
    if value == 0 {
        return 0;
    }
    if context == 0 or context == 2 or context == 4 {
        character = jacpy_integer_value(value);
        jacpy_release(value);
        if jacpy_error_pending() != 0 {
            return 0;
        }
        return jacpy_none() if character < 0 else jacpy_unicode_from_ordinal(character);
    }
    return value;
}

def:priv dialect_reduce(instance: u64, args: u64) -> u64 {
    object_error("TypeError", f"cannot pickle '{type_name(instance)[:100]}' instances");
    return 0;
}

def:priv call_dialect(module: u64, base: u64, kwargs: u64) -> u64 {
    args = jacpy_tuple_new(1 if base != 0 else 0);
    if args == 0 {
        return 0;
    }
    if base != 0 and jacpy_tuple_set_owned(args, 0, jacpy_retain(base)) < 0 {
        jacpy_release(args);
        return 0;
    }
    result = jacpy_call(jacpy_binding_state_get(module, 2), args, kwargs);
    jacpy_release(args);
    return result;
}

glob:priv reader_signature = CallSignature(
         "reader", ["iterable", "dialect"], 1, 2, 2
     ),
     writer_signature = CallSignature("writer", ["fileobj", "dialect"], 1, 2, 2),
     register_signature = CallSignature(
         "register_dialect", ["name", "dialect"], 1, 2, 2
     );

def:priv reader_create_bound(args: BoundArguments) -> u64 {
    instance = jacpy_binding_allocate(jacpy_binding_state_get(args.context, 3));
    if instance == 0 {
        return 0;
    }
    state = CsvReaderState(references=[u64(0), u64(0)], native=csv_reader());
    if jacpy_binding_native_set(instance, reader_type.handle, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    state.references[1] = jacpy_iter(args.values[0]);
    if state.references[1] == 0 {
        jacpy_release(instance);
        return 0;
    }
    state.references[0] = call_dialect(args.context, args.values[1], args.keywords);
    if state.references[0] == 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv reader_create(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(reader_signature, args, kwargs, reader_create_bound, module, True);
}

def:priv reader_next(instance: u64) -> u64 {
    state = reader_state(instance);
    if state is None {
        return 0;
    }
    module = module_for(instance);
    if module == 0 {
        return 0;
    }
    config = config_for(module);
    if config is None {
        return 0;
    }
    return jacpy_csv_read(
        state.native,
        state.references[1],
        dialect_options(state.references[0]),
        config,
        jacpy_binding_state_get(module, 0)
    );
}

def:priv reader_self(instance: u64) -> u64 {
    return jacpy_retain(instance);
}

def:priv reader_line(instance: u64, context: u64) -> u64 {
    state = reader_state(instance);
    return jacpy_int(jacpy_csv_reader_line(state.native))
        if state is not None
        else u64(0);
}

def:priv reader_dialect(instance: u64, context: u64) -> u64 {
    state = reader_state(instance);
    if state is None {
        return 0;
    }
    if state.references[0] == 0 {
        object_error("AttributeError", "dialect");
        return 0;
    }
    return jacpy_retain(state.references[0]);
}

def:priv writer_create_bound(args: BoundArguments) -> u64 {
    instance = jacpy_binding_allocate(jacpy_binding_state_get(args.context, 4));
    if instance == 0 {
        return 0;
    }
    state = CsvWriterState(references=[u64(0), u64(0)], native=csv_writer());
    if jacpy_binding_native_set(instance, writer_type.handle, state) < 0 {
        jacpy_release(instance);
        return 0;
    }
    state.references[1] = jacpy_optional_attr(args.values[0], "write");
    if jacpy_error_pending() != 0 {
        jacpy_release(instance);
        return 0;
    }
    if state.references[1] == 0 or jacpy_callable(state.references[1]) == 0 {
        jacpy_release(instance);
        object_error("TypeError", "argument 1 must have a \"write\" method");
        return 0;
    }
    state.references[0] = call_dialect(args.context, args.values[1], args.keywords);
    if state.references[0] == 0 {
        jacpy_release(instance);
        return 0;
    }
    return instance;
}

def:priv writer_create(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(writer_signature, args, kwargs, writer_create_bound, module, True);
}

def:priv writer_write(instance: u64, row: u64, many: i64) -> u64 {
    state = writer_state(instance);
    if state is None {
        return 0;
    }
    module = module_for(instance);
    if module == 0 {
        return 0;
    }
    return jacpy_csv_write(
        state.native,
        row,
        state.references[1],
        dialect_options(state.references[0]),
        jacpy_binding_state_get(module, 0),
        many
    );
}

def:priv writer_row(instance: u64, row: u64) -> u64 {
    return writer_write(instance, row, 0);
}

def:priv writer_rows(instance: u64, rows: u64) -> u64 {
    return writer_write(instance, rows, 1);
}

def:priv writer_dialect(instance: u64, context: u64) -> u64 {
    state = writer_state(instance);
    if state is None {
        return 0;
    }
    if state.references[0] == 0 {
        object_error("AttributeError", "dialect");
        return 0;
    }
    return jacpy_retain(state.references[0]);
}

def:priv registry(module: u64, key: u64, value: u64, operation: i64) -> u64 {
    return jacpy_csv_registry(
        jacpy_binding_state_get(module, 1),
        key,
        value,
        jacpy_binding_state_get(module, 0),
        operation
    );
}

def:priv register_bound(args: BoundArguments) -> u64 {
    if jacpy_is_unicode(args.values[0]) == 0 {
        object_error("TypeError", "dialect name must be a string");
        return 0;
    }
    dialect = call_dialect(args.context, args.values[1], args.keywords);
    if dialect == 0 {
        return 0;
    }
    result = registry(args.context, args.values[0], dialect, 2);
    jacpy_release(dialect);
    return result;
}

def:priv register_dialect(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(register_signature, args, kwargs, register_bound, module, True);
}

glob:priv get_signature = CallSignature("get_dialect", ["name"], 1, 1),
     unregister_signature = CallSignature("unregister_dialect", ["name"], 1, 1),
     limit_signature = CallSignature("field_size_limit", ["new_limit"], 0, 1);

def:priv get_bound(args: BoundArguments) -> u64 {
    return registry(args.context, args.values[0], 0, 1);
}

def:priv unregister_bound(args: BoundArguments) -> u64 {
    return registry(args.context, args.values[0], 0, 3);
}

def:priv get_dialect(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(get_signature, args, kwargs, get_bound, module);
}

def:priv unregister_dialect(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(unregister_signature, args, kwargs, unregister_bound, module);
}

def:priv list_dialects(module: u64, unused: u64) -> u64 {
    return registry(module, 0, 0, 0);
}

def:priv limit_bound(args: BoundArguments) -> u64 {
    config = config_for(args.context);
    if config is None {
        return 0;
    }
    old = config.limit;
    if args.values[0] != 0 {
        if jacpy_is_exact_long(args.values[0]) == 0 {
            object_error("TypeError", "limit must be an integer");
            return 0;
        }
        value = jacpy_ssize(args.values[0]);
        if value == -1 and jacpy_error_pending() != 0 {
            return 0;
        }
        config.limit = value;
    }
    return jacpy_int(old);
}

def:priv field_size_limit(module: u64, args: u64, kwargs: u64) -> u64 {
    return invoke(limit_signature, args, kwargs, limit_bound, module);
}

def:priv dialect_deallocate(instance: u64) {
    dispose_payload(instance, dialect_type.handle);
}

def:priv dialect_clear(instance: u64) -> i32 {
    return clear_payload(instance, dialect_type.handle);
}

def:priv dialect_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, dialect_type.handle, visitor, context);
}

def:priv reader_deallocate(instance: u64) {
    dispose_payload(instance, reader_type.handle);
}

def:priv reader_clear(instance: u64) -> i32 {
    return clear_payload(instance, reader_type.handle);
}

def:priv reader_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, reader_type.handle, visitor, context);
}

def:priv writer_deallocate(instance: u64) {
    dispose_payload(instance, writer_type.handle);
}

def:priv writer_clear(instance: u64) -> i32 {
    return clear_payload(instance, writer_type.handle);
}

def:priv writer_traverse(instance: u64, visitor: u64, context: u64) -> i32 {
    return traverse_payload(instance, writer_type.handle, visitor, context);
}

glob:priv dialect_type = TypeDefinition(
         "_csv.Dialect",
         "CSV dialect",
         [
             MethodDefinition(
                 "__reduce__",
                 MethodCallbacks(positional=dialect_reduce),
                 "CSV dialects cannot be pickled.",
                 flags=1
             ),
             MethodDefinition(
                 "__reduce_ex__",
                 MethodCallbacks(positional=dialect_reduce),
                 "CSV dialects cannot be pickled.",
                 flags=1
             )
         ],
         u64(TypeFlags.GC.value | TypeFlags.BASETYPE.value | TypeFlags.IMMUTABLE.value),
         TypeHooks(
             create=dialect_create,
             clear=dialect_clear,
             traverse=dialect_traverse,
             dealloc=dialect_deallocate
         ),
         [
             PropertyDefinition(
                 option_names[i],
                 PropertyCallbacks(read=dialect_option),
                 u64(i),
                 doc=option_names[i]
             ) for i in range(8)
         ]
     ),
     reader_type = TypeDefinition(
         "_csv.reader",
         "CSV reader",
         [],
         u64(
             TypeFlags.GC.value
                 | TypeFlags.BASETYPE.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.DISALLOW_INSTANTIATION.value
         ),
         TypeHooks(
             iter=reader_self,
             next=reader_next,
             clear=reader_clear,
             traverse=reader_traverse,
             dealloc=reader_deallocate
         ),
         [
             PropertyDefinition(
                 "line_num",
                 PropertyCallbacks(read=reader_line),
                 doc="Source line number"
             ),
             PropertyDefinition(
                 "dialect",
                 PropertyCallbacks(read=reader_dialect),
                 doc="Parsing dialect"
             )
         ]
     ),
     writer_type = TypeDefinition(
         "_csv.writer",
         "CSV writer",
         [
             MethodDefinition(
                 "writerow",
                 MethodCallbacks(positional=writer_row),
                 "writerow($self, row, /)\n--\n\nWrite a CSV record.",
                 flags=8
             ),
             MethodDefinition(
                 "writerows",
                 MethodCallbacks(positional=writer_rows),
                 "writerows($self, rows, /)\n--\n\nWrite CSV records.",
                 flags=8
             )
         ],
         u64(
             TypeFlags.GC.value
                 | TypeFlags.BASETYPE.value
                 | TypeFlags.IMMUTABLE.value
                 | TypeFlags.DISALLOW_INSTANTIATION.value
         ),
         TypeHooks(
             clear=writer_clear, traverse=writer_traverse, dealloc=writer_deallocate
         ),
         [
             PropertyDefinition(
                 "dialect",
                 PropertyCallbacks(read=writer_dialect),
                 doc="Writing dialect"
             )
         ]
     );

def:priv execute(module: u64) -> i32 {
    config = CsvConfig();
    jacpy_binding_module_native_set(module, config);
    if not add_state_owned(
        module, 0, "Error", jacpy_binding_exception("_csv.Error", "", "")
    ) {
        return i32(-1);
    }
    if not add_state_owned(module, 1, "_dialects", jacpy_dict_new()) {
        return i32(-1);
    }
    if not add_state_owned(module, 2, "Dialect", dialect_type.create(module)) {
        return i32(-1);
    }
    if not add_state_owned(module, 3, "Reader", reader_type.create(module)) {
        return i32(-1);
    }
    if not add_state_owned(module, 4, "Writer", writer_type.create(module)) {
        return i32(-1);
    }
    styles = [
        "QUOTE_MINIMAL",
        "QUOTE_ALL",
        "QUOTE_NONNUMERIC",
        "QUOTE_NONE",
        "QUOTE_STRINGS",
        "QUOTE_NOTNULL"
    ];
    for i in range(len(styles)) {
        if not add_owned(module, styles[i], jacpy_int(i64(i))) {
            return i32(-1);
        }
    }
    return i32(0);
}

glob:priv definition = ModuleDefinition(
         "_csv",
         "CSV algorithms implemented in native Jac.",
         [
             MethodDefinition(
                 "reader",
                 MethodCallbacks(keywords=reader_create),
                 "reader($module, iterable, /, dialect='excel', **fmtparams)\n--\n\nCSV operation."
             ),
             MethodDefinition(
                 "writer",
                 MethodCallbacks(keywords=writer_create),
                 "writer($module, fileobj, /, dialect='excel', **fmtparams)\n--\n\nCSV operation."
             ),
             MethodDefinition(
                 "register_dialect",
                 MethodCallbacks(keywords=register_dialect),
                 "register_dialect($module, name, /, dialect='excel', **fmtparams)\n--\n\nCSV operation."
             ),
             MethodDefinition(
                 "get_dialect",
                 MethodCallbacks(keywords=get_dialect),
                 "get_dialect($module, /, name)\n--\n\nCSV operation."
             ),
             MethodDefinition(
                 "unregister_dialect",
                 MethodCallbacks(keywords=unregister_dialect),
                 "unregister_dialect($module, /, name)\n--\n\nCSV operation."
             ),
             MethodDefinition(
                 "field_size_limit",
                 MethodCallbacks(keywords=field_size_limit),
                 "field_size_limit($module, /, new_limit=<unrepresentable>)\n--\n\nCSV operation."
             ),
             MethodDefinition(
                 "list_dialects",
                 MethodCallbacks(positional=list_dialects),
                 "list_dialects($module, /)\n--\n\nList registered dialects.",
                 flags=4
             )
         ],
         ModuleHooks(execute=execute),
         5
     );

def:pub PyInit__csv -> u64 {
    return definition.initialize();
}

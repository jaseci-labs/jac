impl SessionState.traverse_refs(visitor: ptr, context: ptr) -> i32 {
    return i32(0);
}

impl SessionState.clear {}

impl failure(kind: ptr[PyObject], message: str) -> boundary_failure {
    object_error(kind, message);
    return boundary_failure();
}

impl kernel_failure(error: KernelError) -> ptr[PyObject] {
    object_error(handles.error, str(error));
    return NULL;
}

impl internal_failure(error: Exception) -> ptr[PyObject] {
    object_error(PyExc_SystemError, "jac_kernel: internal compiler error: " + str(error));
    return NULL;
}

impl entries_of(value: ptr[PyObject], what: str) -> list[DictEntry] {
    if jacpy_is_dict(value) == 0 {
        raise failure(
            PyExc_TypeError, what + " must be a dict, not " + type_name(value)
        );
    }
    entries: list[DictEntry] = [];
    position: i64 = 0;
    key: ptr[PyObject] = NULL;
    item: ptr[PyObject] = NULL;
    while PyDict_Next(value, &mut position, &mut key, &mut item) != 0 {
        if jacpy_is_unicode(key) == 0 {
            raise failure(PyExc_TypeError, what + " keys must be str");
        }
        entries.append(DictEntry(name=text_value(key), value=item));
    }
    return entries;
}

impl text_of(value: ptr[PyObject], what: str) -> str {
    if jacpy_is_unicode(value) == 0 {
        raise failure(PyExc_TypeError, what + " must be a str, not " + type_name(value));
    }
    return text_value(value);
}

impl optional_text_of(value: ptr[PyObject], what: str) -> (str | None) {
    if value == Py_None {
        return None;
    }
    return text_of(value, what);
}

impl int_of(value: ptr[PyObject], what: str) -> int {
    if jacpy_is_long(value) == 0 or jacpy_is_bool(value) != 0 {
        raise failure(
            PyExc_TypeError, what + " must be an int, not " + type_name(value)
        );
    }
    number = PyLong_AsLongLong(value);
    if jacpy_error_pending() != 0 {
        raise boundary_failure();
    }
    return int(number);
}

impl optional_int_of(value: ptr[PyObject], what: str) -> (int | None) {
    if value == Py_None {
        return None;
    }
    return int_of(value, what);
}

impl flag_of(value: ptr[PyObject], what: str) -> bool {
    if jacpy_is_bool(value) == 0 {
        raise failure(PyExc_TypeError, what + " must be a bool, not " + type_name(value));
    }
    return PyObject_IsTrue(value) == 1;
}

impl optional_flag_of(value: ptr[PyObject], what: str) -> (bool | None) {
    if value == Py_None {
        return None;
    }
    return flag_of(value, what);
}

impl texts_of(value: ptr[PyObject], what: str) -> list[str] {
    if jacpy_is_list(value) == 0 {
        raise failure(
            PyExc_TypeError, what + " must be a list of str, not " + type_name(value)
        );
    }
    out: list[str] = [];
    for index in range(int(jacpy_sequence_size(value))) {
        item = jacpy_sequence_item(value, i64(index));
        try {
            out.append(text_of(item, what + "[" + str(index) + "]"));
        } finally {
            jacpy_release(item);
        }
    }
    return out;
}

impl optional_texts_of(value: ptr[PyObject], what: str) -> (list[str] | None) {
    if value == Py_None {
        return None;
    }
    return texts_of(value, what);
}

impl text_map_of(value: ptr[PyObject], what: str) -> dict[str, str] {
    out: dict[str, str] = {};
    for pair in entries_of(value, what) {
        out[pair.name] = text_of(pair.value, what + "[" + pair.name + "]");
    }
    return out;
}

impl options_of(value: ptr[PyObject]) -> CompileOptions {
    if value == Py_None {
        return CompileOptions();
    }
    symtab_ir_only = False;
    no_cgen = False;
    native_parity = False;
    native_required = False;
    native_require: (list[str] | None) = None;
    iface_ok = False;
    need_full_ast = False;
    native_tree_demand = False;
    skip_analysis = False;
    skip_native_engine = False;
    no_ir_cache = False;
    resolve_annex_parent = False;
    aot_mode = False;
    native_unit = False;
    kernel_build = False;
    native_link_mode: (str | None) = None;
    force_codespace = "";
    memory_profile: (str | None) = None;
    na_gc_mode: (str | None) = None;
    nogc_enforce_all: (bool | None) = None;
    na_borrow_infer = True;
    memory_enforce: (list[str] | None) = None;
    memory_exempt: (list[str] | None) = None;
    native_threads: (int | None) = None;
    rc_debug_codegen: (bool | None) = None;
    native_target: (str | None) = None;
    native_tls = False;
    native_sjlj = False;
    native_unchecked_views = False;
    native_direct_c_entries = False;
    native_heap = "";
    native_debug: (bool | None) = None;
    opt_level: (int | None) = None;
    dump_ir_path: (str | None) = None;
    debug_ir: (bool | None) = None;
    rc_stats: (bool | None) = None;
    nogc_debug: (bool | None) = None;
    na_debug: (bool | None) = None;
    suppress_codes: list[str] = [];
    default_codespace = "";
    app_kind = "";
    target_app = "";
    entry_point = "";
    ui = "";
    project_root: (str | None) = None;
    client_source_root = "";
    native_module_walk_order: (str | None) = None;
    strict_dependencies = False;
    package_canonical = False;
    na_move_flow = True;
    for pair in entries_of(value, "options") {
        name = pair.name;
        field = pair.value;
        what = "options[" + name + "]";
        if name == "symtab_ir_only" {
            symtab_ir_only = flag_of(field, what);
        } elif name == "no_cgen" {
            no_cgen = flag_of(field, what);
        } elif name == "native_parity" {
            native_parity = flag_of(field, what);
        } elif name == "native_required" {
            native_required = flag_of(field, what);
        } elif name == "native_require" {
            native_require = optional_texts_of(field, what);
        } elif name == "iface_ok" {
            iface_ok = flag_of(field, what);
        } elif name == "need_full_ast" {
            need_full_ast = flag_of(field, what);
        } elif name == "native_tree_demand" {
            native_tree_demand = flag_of(field, what);
        } elif name == "skip_analysis" {
            skip_analysis = flag_of(field, what);
        } elif name == "skip_native_engine" {
            skip_native_engine = flag_of(field, what);
        } elif name == "no_ir_cache" {
            no_ir_cache = flag_of(field, what);
        } elif name == "resolve_annex_parent" {
            resolve_annex_parent = flag_of(field, what);
        } elif name == "aot_mode" {
            aot_mode = flag_of(field, what);
        } elif name == "native_unit" {
            native_unit = flag_of(field, what);
        } elif name == "kernel_build" {
            kernel_build = flag_of(field, what);
        } elif name == "native_link_mode" {
            native_link_mode = optional_text_of(field, what);
        } elif name == "force_codespace" {
            force_codespace = text_of(field, what);
        } elif name == "memory_profile" {
            memory_profile = optional_text_of(field, what);
        } elif name == "na_gc_mode" {
            na_gc_mode = optional_text_of(field, what);
        } elif name == "nogc_enforce_all" {
            nogc_enforce_all = optional_flag_of(field, what);
        } elif name == "na_borrow_infer" {
            na_borrow_infer = flag_of(field, what);
        } elif name == "memory_enforce" {
            memory_enforce = optional_texts_of(field, what);
        } elif name == "memory_exempt" {
            memory_exempt = optional_texts_of(field, what);
        } elif name == "native_threads" {
            native_threads = optional_int_of(field, what);
        } elif name == "rc_debug_codegen" {
            rc_debug_codegen = optional_flag_of(field, what);
        } elif name == "native_target" {
            native_target = optional_text_of(field, what);
        } elif name == "native_tls" {
            native_tls = flag_of(field, what);
        } elif name == "native_sjlj" {
            native_sjlj = flag_of(field, what);
        } elif name == "native_unchecked_views" {
            native_unchecked_views = flag_of(field, what);
        } elif name == "native_direct_c_entries" {
            native_direct_c_entries = flag_of(field, what);
        } elif name == "native_heap" {
            native_heap = text_of(field, what);
        } elif name == "native_debug" {
            native_debug = optional_flag_of(field, what);
        } elif name == "opt_level" {
            opt_level = optional_int_of(field, what);
        } elif name == "dump_ir_path" {
            dump_ir_path = optional_text_of(field, what);
        } elif name == "debug_ir" {
            debug_ir = optional_flag_of(field, what);
        } elif name == "rc_stats" {
            rc_stats = optional_flag_of(field, what);
        } elif name == "nogc_debug" {
            nogc_debug = optional_flag_of(field, what);
        } elif name == "na_debug" {
            na_debug = optional_flag_of(field, what);
        } elif name == "suppress_codes" {
            suppress_codes = texts_of(field, what);
        } elif name == "default_codespace" {
            default_codespace = text_of(field, what);
        } elif name == "app_kind" {
            app_kind = text_of(field, what);
        } elif name == "target_app" {
            target_app = text_of(field, what);
        } elif name == "entry_point" {
            entry_point = text_of(field, what);
        } elif name == "ui" {
            ui = text_of(field, what);
        } elif name == "project_root" {
            project_root = optional_text_of(field, what);
        } elif name == "client_source_root" {
            client_source_root = text_of(field, what);
        } elif name == "native_module_walk_order" {
            native_module_walk_order = optional_text_of(field, what);
        } elif name == "strict_dependencies" {
            strict_dependencies = flag_of(field, what);
        } elif name == "package_canonical" {
            package_canonical = flag_of(field, what);
        } elif name == "na_move_flow" {
            na_move_flow = flag_of(field, what);
        } else {
            raise failure(PyExc_TypeError, "unknown compile option '" + name + "'");
        }
    }
    return CompileOptions(
        symtab_ir_only=symtab_ir_only,
        no_cgen=no_cgen,
        native_parity=native_parity,
        native_required=native_required,
        native_require=native_require,
        iface_ok=iface_ok,
        need_full_ast=need_full_ast,
        native_tree_demand=native_tree_demand,
        skip_analysis=skip_analysis,
        skip_native_engine=skip_native_engine,
        no_ir_cache=no_ir_cache,
        resolve_annex_parent=resolve_annex_parent,
        aot_mode=aot_mode,
        native_unit=native_unit,
        kernel_build=kernel_build,
        native_link_mode=native_link_mode,
        force_codespace=force_codespace,
        memory_profile=memory_profile,
        na_gc_mode=na_gc_mode,
        nogc_enforce_all=nogc_enforce_all,
        na_borrow_infer=na_borrow_infer,
        memory_enforce=memory_enforce,
        memory_exempt=memory_exempt,
        native_threads=native_threads,
        rc_debug_codegen=rc_debug_codegen,
        native_target=native_target,
        native_tls=native_tls,
        native_sjlj=native_sjlj,
        native_unchecked_views=native_unchecked_views,
        native_direct_c_entries=native_direct_c_entries,
        native_heap=native_heap,
        native_debug=native_debug,
        opt_level=opt_level,
        dump_ir_path=dump_ir_path,
        debug_ir=debug_ir,
        rc_stats=rc_stats,
        nogc_debug=nogc_debug,
        na_debug=na_debug,
        suppress_codes=suppress_codes,
        default_codespace=default_codespace,
        app_kind=app_kind,
        target_app=target_app,
        entry_point=entry_point,
        ui=ui,
        project_root=project_root,
        client_source_root=client_source_root,
        native_module_walk_order=native_module_walk_order,
        strict_dependencies=strict_dependencies,
        package_canonical=package_canonical,
        na_move_flow=na_move_flow
    );
}

impl compile_request_of(value: ptr[PyObject]) -> CompileRequest {
    paths: list[str] = [];
    has_paths = False;
    project_root = "";
    search_paths: list[str] = [];
    package_root = "";
    options = CompileOptions();
    sources: dict[str, str] = {};
    products: list[str] = ["bytecode"];
    for pair in entries_of(value, "CompileRequest") {
        what = "CompileRequest." + pair.name;
        if pair.name == "paths" {
            paths = texts_of(pair.value, what);
            has_paths = True;
        } elif pair.name == "project_root" {
            project_root = text_of(pair.value, what);
        } elif pair.name == "search_paths" {
            search_paths = texts_of(pair.value, what);
        } elif pair.name == "package_root" {
            package_root = text_of(pair.value, what);
        } elif pair.name == "options" {
            options = options_of(pair.value);
        } elif pair.name == "sources" {
            sources = text_map_of(pair.value, what);
        } elif pair.name == "products" {
            products = texts_of(pair.value, what);
        } else {
            raise failure(
                PyExc_TypeError, "CompileRequest has no field '" + pair.name + "'"
            );
        }
    }
    if not has_paths {
        raise failure(PyExc_TypeError, "CompileRequest needs 'paths'");
    }
    return CompileRequest(
        paths=paths,
        project_root=project_root,
        search_paths=search_paths,
        package_root=package_root,
        options=options,
        sources=sources,
        products=products
    );
}

impl check_request_of(value: ptr[PyObject]) -> CheckRequest {
    paths: list[str] = [];
    has_paths = False;
    project_root = "";
    search_paths: list[str] = [];
    package_root = "";
    options = CompileOptions();
    sources: dict[str, str] = {};
    native_coverage = False;
    placements = False;
    closure = False;
    for pair in entries_of(value, "CheckRequest") {
        what = "CheckRequest." + pair.name;
        if pair.name == "paths" {
            paths = texts_of(pair.value, what);
            has_paths = True;
        } elif pair.name == "project_root" {
            project_root = text_of(pair.value, what);
        } elif pair.name == "search_paths" {
            search_paths = texts_of(pair.value, what);
        } elif pair.name == "package_root" {
            package_root = text_of(pair.value, what);
        } elif pair.name == "options" {
            options = options_of(pair.value);
        } elif pair.name == "sources" {
            sources = text_map_of(pair.value, what);
        } elif pair.name == "native_coverage" {
            native_coverage = flag_of(pair.value, what);
        } elif pair.name == "placements" {
            placements = flag_of(pair.value, what);
        } elif pair.name == "closure" {
            closure = flag_of(pair.value, what);
        } else {
            raise failure(
                PyExc_TypeError, "CheckRequest has no field '" + pair.name + "'"
            );
        }
    }
    if not has_paths {
        raise failure(PyExc_TypeError, "CheckRequest needs 'paths'");
    }
    return CheckRequest(
        paths=paths,
        project_root=project_root,
        search_paths=search_paths,
        package_root=package_root,
        options=options,
        sources=sources,
        native_coverage=native_coverage,
        placements=placements,
        closure=closure
    );
}

impl kernel_target_of(value: ptr[PyObject]) -> KernelTarget {
    target = KernelTarget();
    for pair in entries_of(value, "KernelTarget") {
        what = "KernelTarget." + pair.name;
        if pair.name == "format" {
            target.format = int_of(pair.value, what);
        } elif pair.name == "root" {
            target.root = text_of(pair.value, what);
        } elif pair.name == "scope_modules" {
            target.scope_modules = texts_of(pair.value, what);
        } elif pair.name == "root_module" {
            target.root_module = text_of(pair.value, what);
        } elif pair.name == "kernel_unit_rel" {
            target.kernel_unit_rel = texts_of(pair.value, what);
        } elif pair.name == "native_lowered_rel" {
            target.native_lowered_rel = texts_of(pair.value, what);
        } elif pair.name == "native_only_rel" {
            target.native_only_rel = texts_of(pair.value, what);
        } elif pair.name == "native_host_rel" {
            target.native_host_rel = texts_of(pair.value, what);
        } elif pair.name == "link_mode" {
            target.link_mode = text_of(pair.value, what);
        } else {
            raise failure(
                PyExc_TypeError, "KernelTarget has no field '" + pair.name + "'"
            );
        }
    }
    if target.format != KERNEL_TARGET_FORMAT {
        raise failure(PyExc_TypeError, "KernelTarget is not a format this kernel reads");
    }
    return target;
}

impl kernel_build_request_of(value: ptr[PyObject]) -> KernelBuildRequest {
    target: (KernelTarget | None) = None;
    output = "";
    triple = "";
    search_paths: list[str] = [];
    package_root = "";
    for pair in entries_of(value, "KernelBuildRequest") {
        what = "KernelBuildRequest." + pair.name;
        if pair.name == "target" {
            target = kernel_target_of(pair.value);
        } elif pair.name == "output" {
            output = text_of(pair.value, what);
        } elif pair.name == "triple" {
            triple = text_of(pair.value, what);
        } elif pair.name == "search_paths" {
            search_paths = texts_of(pair.value, what);
        } elif pair.name == "package_root" {
            package_root = text_of(pair.value, what);
        } else {
            raise failure(
                PyExc_TypeError, "KernelBuildRequest has no field '" + pair.name + "'"
            );
        }
    }
    if target is None {
        raise failure(PyExc_TypeError, "KernelBuildRequest needs 'target'");
    }
    return KernelBuildRequest(
        target=target,
        output=output,
        triple=triple,
        search_paths=search_paths,
        package_root=package_root
    );
}

impl put(record: ptr[PyObject], key: str, value: ptr[PyObject]) {
    required(value);
    status = dict_set_text(record, key, value);
    jacpy_release(value);
    checked(i64(status));
}

impl append(items: ptr[PyObject], value: ptr[PyObject]) {
    checked(jacpy_list_append_owned(items, required(value)));
}

impl new_record -> ptr[PyObject] {
    return required(PyDict_New());
}

impl new_list -> ptr[PyObject] {
    return required(jacpy_list_new());
}

impl int_object(value: int) -> ptr[PyObject] {
    return required(PyLong_FromLongLong(i64(value)));
}

impl flag_object(value: bool) -> ptr[PyObject] {
    return required(PyBool_FromLong(i64(1 if value else 0)));
}

impl none_object -> ptr[PyObject] {
    return Py_NewRef(Py_None);
}

impl texts_object(values: list[str]) -> ptr[PyObject] {
    items = new_list();
    try {
        for value in values {
            append(items, text_object(value));
        }
    } except boundary_failure as error {
        jacpy_release(items);
        raise error;
    }
    return items;
}

impl ints_object(values: list[int]) -> ptr[PyObject] {
    items = new_list();
    try {
        for value in values {
            append(items, int_object(value));
        }
    } except boundary_failure as error {
        jacpy_release(items);
        raise error;
    }
    return items;
}

impl span_object(span: SourceSpan) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "path", text_object(span.path));
        put(record, "line", int_object(span.line));
        put(record, "col", int_object(span.col));
        put(record, "end_line", int_object(span.end_line));
        put(record, "end_col", int_object(span.end_col));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl spans_object(spans: list[SourceSpan]) -> ptr[PyObject] {
    items = new_list();
    try {
        for span in spans {
            append(items, span_object(span));
        }
    } except boundary_failure as error {
        jacpy_release(items);
        raise error;
    }
    return items;
}

impl diagnostic_object(diagnostic: KernelDiagnostic) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "code", text_object(diagnostic.code));
        put(record, "severity", text_object(diagnostic.severity));
        put(record, "message", text_object(diagnostic.message));
        put(record, "span", span_object(diagnostic.span));
        put(record, "help", text_object(diagnostic.help));
        put(record, "pass_name", text_object(diagnostic.pass_name));
        related = new_list();
        put(record, "related", related);
        for note in diagnostic.related {
            row = new_record();
            append(related, row);
            put(row, "label", text_object(note.label));
            put(row, "span", span_object(note.span));
        }
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl diagnostics_object(diagnostics: list[KernelDiagnostic]) -> ptr[PyObject] {
    items = new_list();
    try {
        for diagnostic in diagnostics {
            append(items, diagnostic_object(diagnostic));
        }
    } except boundary_failure as error {
        jacpy_release(items);
        raise error;
    }
    return items;
}

impl demotions_object(demotions: list[NativeDemotion]) -> ptr[PyObject] {
    items = new_list();
    try {
        for demotion in demotions {
            row = new_record();
            append(items, row);
            put(row, "symbol", text_object(demotion.symbol));
            put(row, "kind", text_object(demotion.kind));
            put(row, "reason", text_object(demotion.reason));
            put(row, "code", text_object(demotion.code));
            put(row, "span", span_object(demotion.span));
        }
    } except boundary_failure as error {
        jacpy_release(items);
        raise error;
    }
    return items;
}

impl code_object(unit: CompiledUnit) -> ptr[PyObject] {
    code = unit.code;
    unit.code = NULL;
    if code == NULL {
        return none_object();
    }
    if jacpy_is_code(code) == 0 {
        jacpy_release(code);
        raise failure(
            PyExc_SystemError,
            "jac_kernel: internal compiler error: the unit for "
                + unit.path
                + " carries no code object"
        );
    }
    return code;
}

impl sections_object(sections: dict[int, bytes]) -> ptr[PyObject] {
    record = new_record();
    try {
        for (tag, data) in sections.items() {
            key = int_object(tag);
            try {
                value = required(write_buffer(data));
                status = PyDict_SetItem(record, key, value);
                jacpy_release(value);
                checked(i64(status));
            } finally {
                jacpy_release(key);
            }
        }
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl unit_object(unit: CompiledUnit) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "path", text_object(unit.path));
        put(record, "module_name", text_object(unit.module_name));
        put(record, "code", code_object(unit));
        put(record, "interface", write_buffer(unit.interface));
        put(record, "placement", text_object(unit.placement));
        put(record, "client_js", text_object(unit.client_js));
        put(record, "native_object", write_buffer(unit.native_object));
        put(record, "native_iface", text_object(unit.native_iface));
        put(record, "native_deps", texts_object(unit.native_deps));
        put(record, "native_ir", text_object(unit.native_ir));
        put(record, "native_layout", text_object(unit.native_layout));
        put(record, "demoted", demotions_object(unit.demoted));
        put(record, "jac_deps", texts_object(unit.jac_deps));
        put(record, "app", text_object(unit.app));
        put(record, "persistence", texts_object(unit.persistence));
        put(record, "import_edges", texts_object(unit.import_edges));
        put(record, "interop", text_object(unit.interop));
        put(record, "client_manifest", text_object(unit.client_manifest));
        put(record, "iface_shape", text_object(unit.iface_shape));
        put(record, "effects", text_object(unit.effects));
        put(record, "sections", sections_object(unit.sections));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl compile_result_object(result: CompileResult) -> ptr[PyObject] {
    record = new_record();
    try {
        units = new_list();
        put(record, "units", units);
        for unit in result.units {
            append(units, unit_object(unit));
        }
        put(record, "errors", diagnostics_object(result.errors));
        put(record, "warnings", diagnostics_object(result.warnings));
        put(record, "reached", texts_object(result.reached));
        reads = new_list();
        put(record, "reads", reads);
        for read in result.reads {
            row = new_record();
            append(reads, row);
            put(row, "path", text_object(read.path));
            put(row, "digest", text_object(read.digest));
        }
    } except boundary_failure as error {
        for unit in result.units {
            if unit.code != NULL {
                jacpy_release(unit.code);
                unit.code = NULL;
            }
        }
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl check_result_object(result: CheckResult) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "errors", diagnostics_object(result.errors));
        put(record, "warnings", diagnostics_object(result.warnings));
        put(record, "reached", texts_object(result.reached));
        coverage = new_list();
        put(record, "coverage", coverage);
        for row in result.coverage {
            item = new_record();
            append(coverage, item);
            put(item, "path", text_object(row.path));
            put(item, "native", int_object(row.native));
            put(item, "demoted", demotions_object(row.demoted));
        }
        placements = new_list();
        put(record, "placements", placements);
        for row in result.placements {
            item = new_record();
            append(placements, item);
            put(item, "path", text_object(row.path));
            put(item, "symbol", text_object(row.symbol));
            put(item, "placement", text_object(row.placement));
            put(item, "reason", text_object(row.reason));
        }
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl kernel_build_result_object(result: KernelBuildResult) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "output", text_object(result.output));
        put(record, "triple", text_object(result.triple));
        put(record, "artifact_sha256", text_object(result.artifact_sha256));
        put(record, "plan_digest", text_object(result.plan_digest));
        put(record, "units", int_object(result.units));
        put(record, "errors", diagnostics_object(result.errors));
        put(record, "warnings", diagnostics_object(result.warnings));
        inputs = new_list();
        put(record, "inputs", inputs);
        for read in result.inputs {
            row = new_record();
            append(inputs, row);
            put(row, "path", text_object(read.path));
            put(row, "digest", text_object(read.digest));
        }
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl completions_object(items: list[CompletionItem]) -> ptr[PyObject] {
    out = new_list();
    try {
        for item in items {
            row = new_record();
            append(out, row);
            put(row, "label", text_object(item.label));
            put(row, "kind", text_object(item.kind));
            put(row, "detail", text_object(item.detail));
            put(row, "insert_text", text_object(item.insert_text));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl hints_object(hints: list[InlayHint]) -> ptr[PyObject] {
    out = new_list();
    try {
        for hint in hints {
            row = new_record();
            append(out, row);
            put(row, "line", int_object(hint.line));
            put(row, "col", int_object(hint.col));
            put(row, "label", text_object(hint.label));
            put(row, "kind", text_object(hint.kind));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl symbol_object(symbol: DocumentSymbol) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "name", text_object(symbol.name));
        put(record, "kind", text_object(symbol.kind));
        put(record, "span", span_object(symbol.span));
        put(record, "children", symbols_object(symbol.children));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl symbols_object(symbols: list[DocumentSymbol]) -> ptr[PyObject] {
    out = new_list();
    try {
        for symbol in symbols {
            append(out, symbol_object(symbol));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl edits_object(edits: list[TextEdit]) -> ptr[PyObject] {
    out = new_list();
    try {
        for edit in edits {
            row = new_record();
            append(out, row);
            put(row, "span", span_object(edit.span));
            put(row, "text", text_object(edit.text));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl compile_call(module: ptr[PyObject], request: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return compile_result_object(compile_request(compile_request_of(request)));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl check_call(module: ptr[PyObject], request: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return check_result_object(check_request(check_request_of(request)));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl build_kernel_call(module: ptr[PyObject], request: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return kernel_build_result_object(
            build_kernel_request(kernel_build_request_of(request))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl open_session_call(
    module: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "open_session", 3, 3);
        state = SessionState(
            session=open_session(
                text_of(args[0], "project_root"),
                texts_of(args[1], "search_paths"),
                text_of(args[2], "package_root")
            )
        );
        instance = required(jacpy_binding_allocate(handles.session));
        if jacpy_binding_native_set(instance, session_type.handle, state) < 0 {
            jacpy_release(instance);
            return NULL;
        }
        return instance;
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_of(instance: ptr[PyObject]) -> KernelSession {
    if jacpy_binding_native_present(instance, session_type.handle) != 0 {
        state = jacpy_binding_native_get(instance, session_type.handle);
        if isinstance(state, SessionState) {
            return state.session;
        }
    }
    raise failure(PyExc_SystemError, "jac_kernel.Session holds no kernel session");
}

impl arguments(
    stack: ptr[ptr[PyObject]], count: i64, method: str, least: int, most: int
) -> list[ptr[PyObject]] {
    given = int(count);
    if given < least or given > most {
        wanted = str(least) if least == most else f"{least} to {most}";
        raise failure(
            PyExc_TypeError,
            f"{method}() takes {wanted} positional arguments ({given} given)"
        );
    }
    view = stack.view(count);
    out: list[ptr[PyObject]] = [];
    for index in range(given) {
        out.append(view[index]);
    }
    return out;
}

impl session_update(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.update", 2, 2);
        session_of(instance).update(
            text_of(args[0], "path"), text_of(args[1], "text")
        );
        return none_object();
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_close(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    try {
        session_of(instance).close(text_of(path, "path"));
        return none_object();
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_forget(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    try {
        session_of(instance).forget(text_of(path, "path"));
        return none_object();
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_rename_module(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.rename_module", 2, 2);
        session_of(instance).rename_module(
            text_of(args[0], "old_path"), text_of(args[1], "new_path")
        );
        return none_object();
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_diagnostics(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return diagnostics_object(
            session_of(instance).diagnostics(text_of(path, "path"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_hover(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.hover", 3, 3);
        return text_object(
            session_of(instance).hover(
                text_of(args[0], "path"), int_of(args[1], "line"), int_of(args[2], "col")
            )
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_definition(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.definition", 3, 3);
        return spans_object(
            session_of(instance).definition(
                text_of(args[0], "path"), int_of(args[1], "line"), int_of(args[2], "col")
            )
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_references(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.references", 3, 3);
        return spans_object(
            session_of(instance).references(
                text_of(args[0], "path"), int_of(args[1], "line"), int_of(args[2], "col")
            )
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_completion(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.completion", 3, 4);
        trigger = text_of(args[3], "trigger") if len(args) == 4 else "";
        return completions_object(
            session_of(instance).completion(
                text_of(args[0], "path"),
                int_of(args[1], "line"),
                int_of(args[2], "col"),
                trigger
            )
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_semantic_tokens(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return ints_object(session_of(instance).semantic_tokens(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_inlay_hints(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.inlay_hints", 3, 3);
        return hints_object(
            session_of(instance).inlay_hints(
                text_of(args[0], "path"),
                int_of(args[1], "first_line"),
                int_of(args[2], "last_line")
            )
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_symbols(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return symbols_object(session_of(instance).symbols(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_rename(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.rename", 4, 4);
        return edits_object(
            session_of(instance).rename(
                text_of(args[0], "path"),
                int_of(args[1], "line"),
                int_of(args[2], "col"),
                text_of(args[3], "new_name")
            )
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_format(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return text_object(session_of(instance).format(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_lint_fix(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return text_object(session_of(instance).lint_fix(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_compile(
    instance: ptr[PyObject], request: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return compile_result_object(
            session_of(instance).compile(compile_request_of(request))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_check(instance: ptr[PyObject], request: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return check_result_object(
            session_of(instance).check(check_request_of(request))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_project_root(instance: ptr[PyObject], context: u64) -> ptr[PyObject] {
    try {
        return text_object(session_of(instance).project_root);
    } except boundary_failure {
        return NULL;
    }
}

impl session_dealloc(instance: ptr[PyObject]) {
    dispose_payload(instance, session_type.handle);
}

impl session_traverse(instance: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    return traverse_payload(instance, session_type.handle, visitor, context);
}

impl session_clear(instance: ptr[PyObject]) -> i32 {
    return clear_payload(instance, session_type.handle);
}

impl execute(module: ptr[PyObject]) -> i32 {
    if not add_state_owned(
        module,
        0,
        "KernelError",
        jacpy_binding_exception(
            "jac_kernel.KernelError",
            NULL,
            "A compile, check or session query the kernel refused."
        )
    ) {
        return i32(-1);
    }
    handles.error = jacpy_binding_state_get(module, 0);
    if not add_state_owned(module, 1, "Session", session_type.create(module)) {
        return i32(-1);
    }
    handles.session = jacpy_binding_state_get(module, 1);
    return i32(0);
}

impl PyInit_jac_kernel -> ptr[PyObject] {
    return definition.initialize();
}

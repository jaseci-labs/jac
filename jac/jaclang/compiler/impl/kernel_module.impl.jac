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
    module_facts = False;
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
        } elif pair.name == "module_facts" {
            module_facts = flag_of(pair.value, what);
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
        closure=closure,
        module_facts=module_facts
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
        put(record, "python_ast", python_ast_object(unit));
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

impl python_ast_object(unit: CompiledUnit) -> ptr[PyObject] {
    tree = unit.python_ast;
    unit.python_ast = NULL;
    if tree == NULL {
        return none_object();
    }
    return tree;
}

impl output_object(output: ToolOutput) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "text", text_object(output.text));
        put(record, "errors", diagnostics_object(output.errors));
        put(record, "warnings", diagnostics_object(output.warnings));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl grammar_object(report: GrammarReport) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "ebnf", text_object(report.ebnf));
        put(record, "rules", int_object(report.rules));
        put(record, "diagnostics", text_object(report.diagnostics));
        put(record, "errors", diagnostics_object(report.errors));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl arch_plan_object(plan: ArchPlan) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "arch_path", text_object(plan.arch_path));
        put(record, "text", text_object(plan.text));
        put(record, "modules", texts_object(plan.modules));
        put(record, "fed", texts_object(plan.fed));
        put(record, "added", int_object(plan.added));
        put(record, "dropped", int_object(plan.dropped));
        put(record, "rules", int_object(plan.rules));
        put(record, "rules_added", int_object(plan.rules_added));
        put(record, "refusal", text_object(plan.refusal));
        put(record, "hint", text_object(plan.hint));
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
            if unit.python_ast != NULL {
                jacpy_release(unit.python_ast);
                unit.python_ast = NULL;
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
        modules = new_list();
        put(record, "modules", modules);
        for fact in result.modules {
            item = new_record();
            append(modules, item);
            put(item, "path", text_object(fact.path));
            put(item, "app", text_object(fact.app));
            put(item, "spaces", texts_object(fact.spaces));
            put(item, "decided", text_object(fact.decided));
            put(item, "client_declared", flag_object(fact.client_declared));
            put(item, "errors", int_object(fact.errors));
            put(item, "imports", texts_object(fact.imports));
        }
        app_edges = new_list();
        put(record, "app_edges", app_edges);
        for app_edge in result.app_edges {
            item = new_record();
            append(app_edges, item);
            put(item, "consumer", text_object(app_edge.consumer));
            put(item, "provider", text_object(app_edge.provider));
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
        return output_object(session_of(instance).format(text_of(path, "path")));
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
        return output_object(session_of(instance).lint_fix(text_of(path, "path")));
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

impl session_dependents(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return texts_object(session_of(instance).dependents(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_set_shared_app_limit(
    instance: ptr[PyObject], limit: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        session_of(instance).set_shared_app_limit(int_of(limit, "limit"));
        return none_object();
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_lint(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return output_object(session_of(instance).lint(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_parse(instance: ptr[PyObject], path: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return output_object(session_of(instance).parse(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_statements(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return spans_object(session_of(instance).statements(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_py_to_jac(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return output_object(session_of(instance).py_to_jac(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_ast_view(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.ast_view", 2, 2);
        return output_object(
            session_of(instance).ast_view(
                text_of(args[0], "path"), text_of(args[1], "view")
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

impl session_explain(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.explain", 2, 3);
        memory_profile = text_of(args[2], "memory_profile") if len(args) == 3 else "";
        return output_object(
            session_of(instance).explain(
                text_of(args[0], "path"), text_of(args[1], "topic"), memory_profile
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

impl session_grammar(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        arguments(stack, count, "Session.grammar", 0, 0);
        return grammar_object(session_of(instance).grammar());
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_arch_plan(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.arch_plan", 2, 4);
        prune = flag_of(args[2], "prune") if len(args) >= 3 else False;
        graph_format = text_of(args[3], "graph_format") if len(args) == 4 else "";
        return arch_plan_object(
            session_of(instance).arch_plan(
                text_of(args[0], "arch_path"),
                text_of(args[1], "action"),
                prune,
                graph_format
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

impl outline_object(outline: ModuleOutline) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "path", text_object(outline.path));
        put(record, "doc", text_object(outline.doc));
        put(record, "files", texts_object(outline.files));
        put(record, "error", text_object(outline.error));
        symbols = new_list();
        put(record, "symbols", symbols);
        for row in outline.symbols {
            item = new_record();
            append(symbols, item);
            put(item, "kind", text_object(row.kind));
            put(item, "name", text_object(row.name));
            put(item, "owner", text_object(row.owner));
            put(item, "file", text_object(row.file));
            put(item, "line", int_object(row.line));
            put(item, "end_line", int_object(row.end_line));
            put(item, "col", int_object(row.col));
            put(item, "doc", text_object(row.doc));
            put(item, "bases", texts_object(row.bases));
            put(item, "signature", text_object(row.signature));
            put(item, "event", text_object(row.event));
            put(item, "type_str", text_object(row.type_str));
            put(item, "target", text_object(row.target));
        }
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl edit_symbols_object(rows: list[EditSymbol]) -> ptr[PyObject] {
    out = new_list();
    try {
        for row in rows {
            item = new_record();
            append(out, item);
            put(item, "key", text_object(row.key));
            put(item, "kind", text_object(row.kind));
            put(item, "line", int_object(row.line));
            put(item, "end_line", int_object(row.end_line));
            put(item, "text", text_object(row.text));
            put(item, "signature", text_object(row.signature));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl wiring_changes_object(rows: list[WiringChange]) -> ptr[PyObject] {
    out = new_list();
    try {
        for row in rows {
            item = new_record();
            append(out, item);
            put(item, "kind", text_object(row.kind));
            put(item, "detail", text_object(row.detail));
            put(item, "module", text_object(row.module));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl wired_files_object(found: WiredFiles) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "owned", flag_object(found.owned));
        put(record, "files", texts_object(found.files));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl wiring_model_object(model: WiringModel) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "arch_path", text_object(model.arch_path));
        put(record, "parsed", flag_object(model.parsed));
        modules = new_list();
        put(record, "modules", modules);
        for row in model.modules {
            item = new_record();
            append(modules, item);
            put(item, "local", text_object(row.local));
            put(item, "file", text_object(row.file));
            put(item, "import_name", text_object(row.import_name));
            put(item, "project", flag_object(row.project));
        }
        edges = new_list();
        put(record, "edges", edges);
        for row in model.edges {
            item = new_record();
            append(edges, item);
            put(item, "provider", text_object(row.provider));
            put(item, "consumer", text_object(row.consumer));
            put(item, "scope", texts_object(row.scope));
            put(item, "names", texts_object(row.names));
            put(item, "form", text_object(row.form));
            put(item, "injected", flag_object(row.injected));
            put(item, "line", int_object(row.line));
            put(item, "crosses", flag_object(row.crosses));
            put(item, "rules", texts_object(row.rules));
            put(item, "violation", text_object(row.violation));
            put(item, "arms", texts_object(row.arms));
        }
        rules = new_list();
        put(record, "rules", rules);
        for row in model.rules {
            item = new_record();
            append(rules, item);
            put(item, "name", text_object(row.name));
            put(item, "sources", texts_object(row.sources));
            put(item, "targets", texts_object(row.targets));
            put(item, "names", texts_object(row.names));
            put(item, "governs", texts_object(row.governs));
        }
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl token_symbols_object(rows: list[TokenSymbol]) -> ptr[PyObject] {
    out = new_list();
    try {
        for row in rows {
            item = new_record();
            append(out, item);
            put(item, "line", int_object(row.line));
            put(item, "col", int_object(row.col));
            put(item, "end_col", int_object(row.end_col));
            put(item, "name", text_object(row.name));
            put(item, "kind", text_object(row.kind));
            put(item, "dotted", text_object(row.dotted));
            put(item, "decl_path", text_object(row.decl_path));
            put(item, "decl_line", int_object(row.decl_line));
            put(item, "decl_col", int_object(row.decl_col));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl token_stream_object(stream: TokenStream) -> ptr[PyObject] {
    record = new_record();
    try {
        tokens = new_list();
        put(record, "tokens", tokens);
        for tok in stream.tokens {
            item = new_record();
            append(tokens, item);
            put(item, "kind", text_object(tok.kind));
            put(item, "value", text_object(tok.value));
            put(item, "line", int_object(tok.line));
            put(item, "col", int_object(tok.col));
            put(item, "end_line", int_object(tok.end_line));
            put(item, "end_col", int_object(tok.end_col));
        }
        put(record, "comments", spans_object(stream.comments));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl symbol_info_object(info: SymbolInfo) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "name", text_object(info.name));
        put(record, "kind", text_object(info.kind));
        put(record, "file", text_object(info.file));
        put(record, "line", int_object(info.line));
        put(record, "col", int_object(info.col));
        put(record, "type_str", text_object(info.type_str));
        put(record, "doc", text_object(info.doc));
        put(record, "signature", text_object(info.signature));
        put(record, "fields", texts_object(info.fields));
        put(record, "abilities", texts_object(info.abilities));
        put(record, "base_classes", texts_object(info.base_classes));
        put(record, "is_genai", flag_object(info.is_genai));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl symbol_infos_object(infos: list[SymbolInfo]) -> ptr[PyObject] {
    out = new_list();
    try {
        for info in infos {
            append(out, symbol_info_object(info));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl source_refs_object(refs: list[SourceRef]) -> ptr[PyObject] {
    out = new_list();
    try {
        for found in refs {
            item = new_record();
            append(out, item);
            put(item, "file", text_object(found.file));
            put(item, "line", int_object(found.line));
            put(item, "col", int_object(found.col));
            put(item, "role", text_object(found.role));
            put(item, "snippet", text_object(found.snippet));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl entry_points_object(points: list[EntryPoint]) -> ptr[PyObject] {
    out = new_list();
    try {
        for point in points {
            item = new_record();
            append(out, item);
            put(item, "walker_name", text_object(point.walker_name));
            put(item, "ability", text_object(point.ability));
            put(item, "node_type", text_object(point.node_type));
            put(item, "event", text_object(point.event));
            put(item, "file", text_object(point.file));
            put(item, "line", int_object(point.line));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl context_slice_object(found: ContextSlice) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "query", text_object(found.query));
        target = found.target;
        if target is None {
            put(record, "target", none_object());
        } else {
            put(record, "target", symbol_info_object(target));
        }
        put(record, "related", symbol_infos_object(found.related));
        put(record, "uses", source_refs_object(found.uses));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl code_diagnostics_object(diags: list[CodeDiagnostic]) -> ptr[PyObject] {
    out = new_list();
    try {
        for diag in diags {
            item = new_record();
            append(out, item);
            put(item, "file", text_object(diag.file));
            put(item, "line", int_object(diag.line));
            put(item, "severity", text_object(diag.severity));
            put(item, "message", text_object(diag.message));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl session_module_outline(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return outline_object(session_of(instance).module_outline(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_edit_symbols(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.edit_symbols", 2, 2);
        return edit_symbols_object(
            session_of(instance).edit_symbols(
                text_of(args[0], "path"), text_of(args[1], "text")
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

impl session_import_texts(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.import_texts", 2, 2);
        return texts_object(
            session_of(instance).import_texts(
                text_of(args[0], "path"), text_of(args[1], "text")
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

impl session_wiring_changes(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.wiring_changes", 3, 3);
        return wiring_changes_object(
            session_of(instance).wiring_changes(
                text_of(args[0], "path"),
                text_of(args[1], "old_text"),
                text_of(args[2], "new_text")
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

impl session_wired_dependents(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.wired_dependents", 2, 2);
        return wired_files_object(
            session_of(instance).wired_dependents(
                text_of(args[0], "head"), texts_of(args[1], "names")
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

impl session_wiring_module_files(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.wiring_module_files", 2, 2);
        return texts_object(
            session_of(instance).wiring_module_files(
                text_of(args[0], "arch_path"), texts_of(args[1], "consumers")
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

impl session_wiring_model(
    instance: ptr[PyObject], arch_path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return wiring_model_object(
            session_of(instance).wiring_model(text_of(arch_path, "arch_path"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_token_symbols(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return token_symbols_object(
            session_of(instance).token_symbols(text_of(path, "path"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_assignment_hints(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return hints_object(session_of(instance).assignment_hints(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_tokens(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.tokens", 2, 2);
        return token_stream_object(
            session_of(instance).tokens(
                text_of(args[0], "path"), text_of(args[1], "text")
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

impl session_code_lookup(
    instance: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return symbol_infos_object(
            session_of(instance).code_lookup(text_of(name, "name"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_code_references(
    instance: ptr[PyObject], name: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return source_refs_object(
            session_of(instance).code_references(text_of(name, "name"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_code_archetypes(
    instance: ptr[PyObject], kind: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return symbol_infos_object(
            session_of(instance).code_archetypes(text_of(kind, "kind"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_code_walkers(
    instance: ptr[PyObject], node_type: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return entry_points_object(
            session_of(instance).code_walkers(text_of(node_type, "node_type"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_code_slice(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.code_slice", 2, 2);
        return context_slice_object(
            session_of(instance).code_slice(
                text_of(args[0], "name"), int_of(args[1], "depth")
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

impl session_code_diagnostics(
    instance: ptr[PyObject], file: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return code_diagnostics_object(
            session_of(instance).code_diagnostics(text_of(file, "file"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_code_refresh(
    instance: ptr[PyObject], file: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        session_of(instance).code_refresh(text_of(file, "file"));
        return none_object();
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl native_build_request_of(value: ptr[PyObject]) -> NativeBuildRequest {
    roots: list[str] = [];
    has_roots = False;
    kind = "";
    output = "";
    project_root = "";
    search_paths: list[str] = [];
    package_root = "";
    options = CompileOptions();
    link_mode = "";
    native_unit = False;
    library_api = False;
    callbacks = False;
    emit_c = False;
    refuse_python_imports = False;
    refuse_demoted = False;
    require_entry = False;
    kernel_entries = False;
    assert_no_rc = False;
    for pair in entries_of(value, "NativeBuildRequest") {
        what = "NativeBuildRequest." + pair.name;
        if pair.name == "roots" {
            roots = texts_of(pair.value, what);
            has_roots = True;
        } elif pair.name == "kind" {
            kind = text_of(pair.value, what);
        } elif pair.name == "output" {
            output = text_of(pair.value, what);
        } elif pair.name == "project_root" {
            project_root = text_of(pair.value, what);
        } elif pair.name == "search_paths" {
            search_paths = texts_of(pair.value, what);
        } elif pair.name == "package_root" {
            package_root = text_of(pair.value, what);
        } elif pair.name == "options" {
            options = options_of(pair.value);
        } elif pair.name == "link_mode" {
            link_mode = text_of(pair.value, what);
        } elif pair.name == "native_unit" {
            native_unit = flag_of(pair.value, what);
        } elif pair.name == "library_api" {
            library_api = flag_of(pair.value, what);
        } elif pair.name == "callbacks" {
            callbacks = flag_of(pair.value, what);
        } elif pair.name == "emit_c" {
            emit_c = flag_of(pair.value, what);
        } elif pair.name == "refuse_python_imports" {
            refuse_python_imports = flag_of(pair.value, what);
        } elif pair.name == "refuse_demoted" {
            refuse_demoted = flag_of(pair.value, what);
        } elif pair.name == "require_entry" {
            require_entry = flag_of(pair.value, what);
        } elif pair.name == "kernel_entries" {
            kernel_entries = flag_of(pair.value, what);
        } elif pair.name == "assert_no_rc" {
            assert_no_rc = flag_of(pair.value, what);
        } else {
            raise failure(
                PyExc_TypeError, "NativeBuildRequest has no field '" + pair.name + "'"
            );
        }
    }
    if not has_roots or not kind {
        raise failure(PyExc_TypeError, "NativeBuildRequest needs 'roots' and 'kind'");
    }
    return NativeBuildRequest(
        roots=roots,
        kind=kind,
        output=output,
        project_root=project_root,
        search_paths=search_paths,
        package_root=package_root,
        options=options,
        link_mode=link_mode,
        native_unit=native_unit,
        library_api=library_api,
        callbacks=callbacks,
        emit_c=emit_c,
        refuse_python_imports=refuse_python_imports,
        refuse_demoted=refuse_demoted,
        require_entry=require_entry,
        kernel_entries=kernel_entries,
        assert_no_rc=assert_no_rc
    );
}

impl native_build_result_object(result: NativeBuildResult) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "errors", diagnostics_object(result.errors));
        put(record, "warnings", diagnostics_object(result.warnings));
        put(record, "linked", flag_object(result.linked));
        put(record, "reused", flag_object(result.reused));
        put(record, "output", text_object(result.output));
        put(record, "mode", text_object(result.mode));
        put(record, "triple", text_object(result.triple));
        units = new_list();
        put(record, "units", units);
        for unit in result.units {
            row = new_record();
            append(units, row);
            put(row, "path", text_object(unit.path));
            put(row, "digest", text_object(unit.digest));
            put(row, "stamp", text_object(unit.stamp));
        }
        put(record, "recompiled", int_object(result.recompiled));
        put(record, "analysed", int_object(result.analysed));
        put(record, "lowered", int_object(result.lowered));
        put(record, "generated", int_object(result.generated));
        put(record, "sha256", text_object(result.sha256));
        put(record, "plan_digest", text_object(result.plan_digest));
        put(record, "layout_digest", text_object(result.layout_digest));
        put(record, "root_native", flag_object(result.root_native));
        put(record, "has_entry", flag_object(result.has_entry));
        put(record, "python_imports", texts_object(result.python_imports));
        put(record, "demoted", texts_object(result.demoted));
        put(record, "rc_symbols", texts_object(result.rc_symbols));
        put(record, "rc_probes", texts_object(result.rc_probes));
        put(record, "libraries", texts_object(result.libraries));
        callbacks = new_list();
        put(record, "callbacks", callbacks);
        for binding in result.callbacks {
            row = new_record();
            append(callbacks, row);
            put(row, "name", text_object(binding.name));
            put(row, "symbol", text_object(binding.symbol));
            put(row, "ret_type", text_object(binding.ret_type));
            put(row, "param_types", texts_object(binding.param_types));
        }
        put(record, "log", texts_object(result.log));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl native_build_call(module: ptr[PyObject], request: ptr[PyObject]) -> ptr[PyObject] {
    try {
        return native_build_result_object(
            native_build_request(native_build_request_of(request))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl element_space_object(space: ElementSpace) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "name", text_object(space.name));
        put(record, "space", text_object(space.space));
        put(record, "line", int_object(space.line));
        put(record, "dual", flag_object(space.dual));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl element_spaces_object(spaces: list[ElementSpace]) -> ptr[PyObject] {
    out = new_list();
    try {
        for space in spaces {
            append(out, element_space_object(space));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl import_spaces_object(spaces: list[ImportSpace]) -> ptr[PyObject] {
    out = new_list();
    try {
        for space in spaces {
            row = new_record();
            append(out, row);
            put(row, "target", text_object(space.target));
            put(row, "line", int_object(space.line));
            put(row, "client_only", flag_object(space.client_only));
        }
    } except boundary_failure as error {
        jacpy_release(out);
        raise error;
    }
    return out;
}

impl marker_scan_object(scan: MarkerScan) -> ptr[PyObject] {
    record = new_record();
    try {
        put(record, "text", text_object(scan.text));
        put(record, "changed", flag_object(scan.changed));
        put(record, "claims", element_spaces_object(scan.claims));
        put(record, "sv_imports", import_spaces_object(scan.sv_imports));
        put(record, "note", text_object(scan.note));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl access_plan_object(plan: AccessPlan) -> ptr[PyObject] {
    record = new_record();
    try {
        rewrites = new_list();
        put(record, "rewrites", rewrites);
        for rewrite in plan.rewrites {
            row = new_record();
            append(rewrites, row);
            put(row, "path", text_object(rewrite.path));
            put(row, "line", int_object(rewrite.line));
            put(row, "kind", text_object(rewrite.kind));
            put(row, "name", text_object(rewrite.name));
            put(row, "reason", text_object(rewrite.reason));
        }
        put(record, "notes", texts_object(plan.notes));
    } except boundary_failure as error {
        jacpy_release(record);
        raise error;
    }
    return record;
}

impl session_strip_markers(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.strip_markers", 2, 2);
        return marker_scan_object(
            session_of(instance).strip_markers(
                text_of(args[0], "path"), text_of(args[1], "text")
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

impl session_element_spaces(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return element_spaces_object(
            session_of(instance).element_spaces(text_of(path, "path"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_client_imports(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return import_spaces_object(
            session_of(instance).client_imports(text_of(path, "path"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_access_plan(
    instance: ptr[PyObject], project_root: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return access_plan_object(
            session_of(instance).access_plan(text_of(project_root, "project_root"))
        );
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_package_api(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.package_api", 2, 2);
        return text_object(
            session_of(instance).package_api(
                text_of(args[0], "base_root"), texts_of(args[1], "exports")
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

impl session_stub_catalog(
    instance: ptr[PyObject], stack: ptr[ptr[PyObject]], count: i64
) -> ptr[PyObject] {
    try {
        args = arguments(stack, count, "Session.stub_catalog", 3, 3);
        report = session_of(instance).stub_catalog(
            text_of(args[0], "out_path"),
            texts_of(args[1], "only"),
            text_of(args[2], "pkg_dir")
        );
        record = new_record();
        try {
            put(record, "summary", text_object(report.summary));
            put(record, "load_failures", texts_object(report.load_failures));
        } except boundary_failure as error {
            jacpy_release(record);
            raise error;
        }
        return record;
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_npm_sources(
    instance: ptr[PyObject], project_root: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        sources = session_of(instance).npm_sources(text_of(project_root, "project_root"));
        out = new_list();
        try {
            for item in sources {
                row = new_record();
                append(out, row);
                put(row, "npm_path", text_object(item.npm_path));
                put(row, "source_path", text_object(item.source_path));
                put(row, "js", text_object(item.js));
                put(row, "dts", text_object(item.dts));
                put(row, "external_imports", texts_object(item.external_imports));
            }
        } except boundary_failure as error {
            jacpy_release(out);
            raise error;
        }
        return out;
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

impl session_definition_rows(
    instance: ptr[PyObject], path: ptr[PyObject]
) -> ptr[PyObject] {
    try {
        return texts_object(session_of(instance).definition_rows(text_of(path, "path")));
    } except boundary_failure {
        return NULL;
    } except KernelError as error {
        return kernel_failure(error);
    } except Exception as error {
        return internal_failure(error);
    }
}

import from c {
    obj ModuleHooks {
        has execute: Callable[[ptr[PyObject]], i32] = 0,
            traverse: Callable[[ptr[PyObject], ptr, ptr], i32] = 0,
            clear: Callable[[ptr[PyObject]], i32] = 0,
            free: Callable[[ptr[PyObject]], None] = 0;
    }  def jacpy_binding_module(
        name: str, doc: str, count: i64, hooks: ModuleHooks, state_count: i64
    ) -> ptr;  def jacpy_binding_method(
        handle: ptr,
        index: i64,
        name: str,
        keywords:
            Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]],
        positional: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]],
        fast: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]],
        fast_keywords:
            Callable[
                [ptr[PyObject], ptr[ptr[PyObject]], i64, ptr[PyObject]],
                ptr[PyObject]
            ],
        flags: i64,
        doc: str
    ) -> i64;  def jacpy_binding_discard(handle: ptr);  def jacpy_binding_init(
        handle: ptr
    ) -> ptr[PyObject];  def jacpy_binding_state_count(module: ptr[PyObject]) -> i64;  def jacpy_binding_state_get(
        module: ptr[PyObject], index: i64
    ) -> ptr[PyObject];  def jacpy_binding_state_set(
        module: ptr[PyObject], index: i64, value: ptr[PyObject]
    );  def jacpy_binding_exception(
        name: str, base: ptr[PyObject], doc: str
    ) -> ptr[PyObject];
}

import from c {
    def jacpy_binding_module_native_get(module: ptr[PyObject]) -> NativeState;  def jacpy_binding_module_native_set(
        module: ptr[PyObject], state: NativeState
    );  def jacpy_binding_module_native_clear(module: ptr[PyObject]);  def jacpy_binding_module_native_present(
        module: ptr[PyObject]
    ) -> i64;
}

import from c {
    obj VisitProc {
        has call: Callable[[ptr[PyObject], ptr], i32] = 0;
    }
}

def visit_reference(value: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def traverse_state(module: ptr[PyObject], visitor: ptr, context: ptr) -> i32;

def clear_state(module: ptr[PyObject]) -> i32;

def free_state(module: ptr[PyObject]);

import from c {
    obj MethodCallbacks {
        has keywords:
            Callable[[ptr[PyObject], ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            positional: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            fast: Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0,
            fast_keywords:
                Callable[
                    [ptr[PyObject], ptr[ptr[PyObject]], i64, ptr[PyObject]],
                    ptr[PyObject]
                ] = 0;
    }
}

obj MethodDefinition {
    has name: str,
        callbacks: MethodCallbacks,
        doc: str,
        flags: i64 = 3;
}

import from c {
    obj PositionalMethodRecord {
        has ml_name: ptr[u8] = ptr[u8](),
            ml_meth: Callable[[ptr[PyObject], ptr[PyObject]], ptr[PyObject]] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }
}

import from c {
    obj KeywordMethodRecord {
        has ml_name: ptr[u8] = ptr[u8](),
            ml_meth:
                Callable[
                    [ptr[PyObject], ptr[PyObject], ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }  obj FastMethodRecord {
        has ml_name: ptr[u8] = ptr[u8](),
            ml_meth:
                Callable[[ptr[PyObject], ptr[ptr[PyObject]], i64], ptr[PyObject]] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }  obj FastKeywordMethodRecord {
        has ml_name: ptr[u8] = ptr[u8](),
            ml_meth:
                Callable[
                    [ptr[PyObject], ptr[ptr[PyObject]], i64, ptr[PyObject]],
                    ptr[PyObject]
                ] = 0,
            ml_flags: i32 = 0,
            ml_doc: ptr[u8] = ptr[u8]();
    }
}

def method_table(methods: list[MethodDefinition]) -> ptr[PyMethodDef];

def builtin_function(
    definition: MethodDefinition, owner: ptr[PyObject]
) -> ptr[PyObject];

def install_methods(handle: ptr, methods: list[MethodDefinition]) -> bool;

obj ModuleDefinition {
    has handle: ptr = NULL;

    def init(
        name: str,
        doc: str,
        methods: list[MethodDefinition],
        hooks: ModuleHooks = ModuleHooks(),
        state_count: int = 0,
        own_lifecycle: bool = False
    );

    def initialize -> ptr[PyObject];
}

import from c {
    def jacpy_binding_functions(count: i64) -> ptr;  def jacpy_binding_functions_discard(
        handle: ptr
    );  def jacpy_binding_function(
        handle: ptr, index: i64, receiver: ptr[PyObject], module: ptr[PyObject]
    ) -> ptr[PyObject];
}

obj FunctionTable {
    has handle: ptr = NULL;

    def init(methods: list[MethodDefinition]);
    def bind(
        index: int, receiver: ptr[PyObject], module: ptr[PyObject] = NULL
    ) -> ptr[PyObject];
}

def add_state_owned(
    module: ptr[PyObject], index: int, name: str, value: ptr[PyObject]
) -> bool;

def add_owned(module: ptr[PyObject], name: str, value: ptr[PyObject]) -> bool;

impl visit_reference(value: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    if value == 0 {
        return i32(0);
    }
    slot = ptr[VisitProc](__thread_local_block("jac_bindings_module_visit_slot", 8));
    slot.view(1)[0].call = int(visitor);
    return slot.view(1)[0].call(value, context);
}

impl traverse_state(module: ptr[PyObject], visitor: ptr, context: ptr) -> i32 {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        status = state.traverse_refs(visitor, context);
        if status != 0 {
            return status;
        }
    }
    for index in range(int(jacpy_binding_state_count(module))) {
        result = visit_reference(
            jacpy_binding_state_get(module, i64(index)), visitor, context
        );
        if result != 0 {
            return result;
        }
    }
    return i32(0);
}

impl clear_state(module: ptr[PyObject]) -> i32 {
    if jacpy_binding_module_native_present(module) != 0 {
        state = jacpy_binding_module_native_get(module);
        state.clear();
        jacpy_binding_module_native_clear(module);
    }
    for index in range(int(jacpy_binding_state_count(module))) {
        jacpy_binding_state_set(module, i64(index), NULL);
    }
    return i32(0);
}

impl free_state(module: ptr[PyObject]) {
    clear_state(module);
}

impl method_table(methods: list[MethodDefinition]) -> ptr[PyMethodDef] {
    count = len(methods);
    table = ptr[PyMethodDef](PyMem_RawCalloc(u64(count + 1), 32));
    if table.is_null() {
        PyErr_NoMemory();
        return table;
    }
    for index in range(count) {
        method = methods[index];
        name = c_string_copy(method.name);
        doc = c_string_copy(method.doc) if method.doc else ptr[u8]();
        if name.is_null() or (method.doc and doc.is_null()) {
            PyErr_NoMemory();
            return ptr[PyMethodDef]();
        }
        slot = table + index;

        fastcall = (method.flags & 0x80) != 0;
        keywords = (method.flags & 2) != 0;
        if fastcall and keywords {
            fast_keyword = ptr[FastKeywordMethodRecord](slot).view(1);
            fast_keyword[0].ml_name = name;
            fast_keyword[0].ml_meth = method.callbacks.fast_keywords;
            fast_keyword[0].ml_flags = i32(method.flags);
            fast_keyword[0].ml_doc = doc;
        } elif fastcall {
            fast = ptr[FastMethodRecord](slot).view(1);
            fast[0].ml_name = name;
            fast[0].ml_meth = method.callbacks.fast;
            fast[0].ml_flags = i32(method.flags);
            fast[0].ml_doc = doc;
        } elif keywords {
            keyword = ptr[KeywordMethodRecord](slot).view(1);
            keyword[0].ml_name = name;
            keyword[0].ml_meth = method.callbacks.keywords;
            keyword[0].ml_flags = i32(method.flags);
            keyword[0].ml_doc = doc;
        } else {
            positional = ptr[PositionalMethodRecord](slot).view(1);
            positional[0].ml_name = name;
            positional[0].ml_meth = method.callbacks.positional;
            positional[0].ml_flags = i32(method.flags);
            positional[0].ml_doc = doc;
        }
    }
    return table;
}

impl builtin_function(
    definition: MethodDefinition, owner: ptr[PyObject]
) -> ptr[PyObject] {
    record = ptr[PositionalMethodRecord](PyMem_RawCalloc(1, 32));
    if record.is_null() {
        PyErr_NoMemory();
        return NULL;
    }
    record.view(1)[0].ml_name = c_string_copy(definition.name);
    record.view(1)[0].ml_meth = definition.callbacks.positional;
    record.view(1)[0].ml_flags = i32(definition.flags);
    record.view(1)[0].ml_doc = c_string_copy(definition.doc);
    return PyCFunction_NewEx(ptr[PyMethodDef](record), owner, NULL);
}

impl install_methods(handle: ptr, methods: list[MethodDefinition]) -> bool {
    for index in range(len(methods)) {
        method = methods[index];
        if jacpy_binding_method(
            handle,
            i64(index),
            method.name,
            method.callbacks.keywords,
            method.callbacks.positional,
            method.callbacks.fast,
            method.callbacks.fast_keywords,
            method.flags,
            method.doc
        )
            < 0 {
            return False;
        }
    }
    return True;
}

impl ModuleDefinition.init(
    name: str,
    doc: str,
    methods: list[MethodDefinition],
    hooks: ModuleHooks = ModuleHooks(),
    state_count: int = 0,
    own_lifecycle: bool = False
) {
    lifecycle = hooks
        if own_lifecycle
        else ModuleHooks(
            execute=hooks.execute,
            traverse=traverse_state,
            clear=clear_state,
            free=free_state
        );
    self.handle = jacpy_binding_module(
        name, doc, i64(len(methods)), lifecycle, i64(state_count)
    );
    if not self.handle {
        return;
    }
    if not install_methods(self.handle, methods) {
        jacpy_binding_discard(self.handle);
        self.handle = ptr();
    }
}

impl ModuleDefinition.initialize -> ptr[PyObject] {
    return jacpy_binding_init(self.handle);
}

impl FunctionTable.init(methods: list[MethodDefinition]) {
    self.handle = jacpy_binding_functions(i64(len(methods)));
    if self.handle and not install_methods(self.handle, methods) {
        jacpy_binding_functions_discard(self.handle);
        self.handle = ptr();
    }
}

impl FunctionTable.bind(
    index: int, receiver: ptr[PyObject], module: ptr[PyObject] = NULL
) -> ptr[PyObject] {
    return jacpy_binding_function(self.handle, i64(index), receiver, module);
}

impl add_state_owned(
    module: ptr[PyObject], index: int, name: str, value: ptr[PyObject]
) -> bool {
    if value == 0 {
        return False;
    }
    jacpy_binding_state_set(module, i64(index), value);
    return add_owned(module, name, value);
}

impl add_owned(module: ptr[PyObject], name: str, value: ptr[PyObject]) -> bool {
    if value == 0 {
        return False;
    }
    result = jacpy_module_add_object_ref_text(module, name, value);
    jacpy_release(value);
    return result == 0;
}

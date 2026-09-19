"""Owned Python results return through native frames before restoring an error."""
import from jaclang.runtime.cpython.references {
    ObjectResult,
    ReferenceState,
    object_result,
    borrowed_result
}
import from jaclang.runtime.cpython.capi {
    jacpy_import_object,
    jacpy_getattr,
    jacpy_call
}
import from c { def PyGILState_Check -> i32;  }

def:pub gil_held -> i32 {
    return PyGILState_Check();
}

def imported(module_name: u64, name: u64, args: u64, kwargs: u64) -> ObjectResult {
    module = object_result(jacpy_import_object(module_name));
    if module.failed {
        return module;
    }
    callable = object_result(jacpy_getattr(module.reference.value, name));
    if callable.failed {
        return callable;
    }
    return object_result(jacpy_call(callable.reference.value, args, kwargs));
}

def:pub import_call(module_name: u64, name: u64, args: u64, kwargs: u64) -> u64 {
    return imported(module_name, name, args, kwargs).take();
}

def method(value: u64, name: u64, args: u64, kwargs: u64) -> ObjectResult {
    callable = object_result(jacpy_getattr(value, name));
    if callable.failed {
        return callable;
    }
    return object_result(jacpy_call(callable.reference.value, args, kwargs));
}

def:pub method_call(value: u64, name: u64, args: u64, kwargs: u64) -> u64 {
    return method(value, name, args, kwargs).take();
}

def:pub retained_identity(value: u64) -> u64 {
    return borrowed_result(value).take();
}

def:pub release_local(value: u64) {
    reference = borrowed_result(value);
}

def:pub release_alias(value: u64) {
    result = borrowed_result(value);
    alias = result.reference;
    result.reference.clear();
    alias.clear();
}

glob reference_group: ReferenceState = ReferenceState(references=[]);

def:pub clear_group {
    reference_group.clear();
}

def:pub release_group(factory: u64, args: u64) {
    reference_group.references = [jacpy_call(factory, args, u64(0)) for _ in range(3)];
    clear_group();
}

def:pub borrow_null -> u64 {
    return borrowed_result(u64(0)).take();
}

def invoke(value: u64, args: u64, kwargs: u64, witness: u64) -> ObjectResult {
    held = borrowed_result(witness);
    if held.failed {
        return held;
    }
    result = object_result(jacpy_call(value, args, kwargs));
    if result.failed {
        return result;
    }
    return held;
}

def:pub call_with_witness(value: u64, args: u64, kwargs: u64, witness: u64) -> u64 {
    return invoke(value, args, kwargs, witness).take();
}

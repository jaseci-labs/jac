"""Owned runtime values and native exception cleanup at a Python entry point."""
import from jaclang.runtime.python.references {
    ObjectRef,
    PythonFailure,
    owned_object,
    borrowed_object,
    restore_failure
}
import from jaclang.runtime.python.capi {
    jacpy_import_object,
    jacpy_getattr,
    jacpy_call
}

def:pub import_call(module_name: u64, name: u64, args: u64, kwargs: u64) -> u64 {
    try {
        module = owned_object(jacpy_import_object(module_name));
        callable = owned_object(jacpy_getattr(module.value, name));
        result = owned_object(jacpy_call(callable.value, args, kwargs));
        return result.take();
    } except PythonFailure as failure {
        restore_failure(failure);
        return 0;
    }
}

def:pub method_call(value: u64, name: u64, args: u64, kwargs: u64) -> u64 {
    try {
        callable = owned_object(jacpy_getattr(value, name));
        result = owned_object(jacpy_call(callable.value, args, kwargs));
        return result.take();
    } except PythonFailure as failure {
        restore_failure(failure);
        return 0;
    }
}

def:pub retained_identity(value: u64) -> u64 {
    reference = borrowed_object(value);
    return reference.take();
}

def:pub release_local(value: u64) {
    reference = borrowed_object(value);
}

def:pub release_alias(value: u64) {
    reference = borrowed_object(value);
    alias = reference;
    reference.clear();
    alias.clear();
}

def:pub borrow_null -> u64 {
    try {
        reference = borrowed_object(u64(0));
        return reference.take();
    } except PythonFailure as failure {
        restore_failure(failure);
        return 0;
    }
}

def invoke(value: u64, args: u64, kwargs: u64, witness: u64) -> ObjectRef {
    held = borrowed_object(witness);
    return owned_object(jacpy_call(value, args, kwargs));
}

def:pub call_with_witness(value: u64, args: u64, kwargs: u64, witness: u64) -> u64 {
    try {
        result = invoke(value, args, kwargs, witness);
        return result.take();
    } except PythonFailure as failure {
        restore_failure(failure);
        return 0;
    }
}
